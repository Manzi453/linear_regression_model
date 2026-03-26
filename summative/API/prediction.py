from __future__ import annotations

import io
import math
import os
from contextlib import asynccontextmanager
from threading import Lock
from typing import Optional

import pandas as pd
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from model_service import FEATURES, ModelService

service = ModelService()
service_lock = Lock()


def _allowed_origins() -> list[str]:
    configured_origins = os.getenv("ALLOWED_ORIGINS", "")
    render_external_url = os.getenv("RENDER_EXTERNAL_URL", "").strip()

    origins = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5500",
        "http://127.0.0.1:8000",
    ]

    if render_external_url:
        origins.append(render_external_url.rstrip("/"))

    if configured_origins:
        origins.extend(
            origin.strip().rstrip("/")
            for origin in configured_origins.split(",")
            if origin.strip()
        )

    unique_origins: list[str] = []
    for origin in origins:
        if origin not in unique_origins:
            unique_origins.append(origin)

    return unique_origins


@asynccontextmanager
async def lifespan(_: FastAPI):
    with service_lock:
        service.ensure_ready()
    yield


app = FastAPI(
    title="Solar AC Power Prediction API",
    description=(
        "Predict AC power for a solar plant using the best-performing regression "
        "model from Task 1, with validation, retraining, and Swagger UI support."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Accept", "Authorization", "Content-Type", "Origin", "User-Agent"],
)


class PredictionRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "DC_POWER": 1000.0,
                "DAILY_YIELD": 5000.0,
                "TOTAL_YIELD": 7000000.0,
            }
        }
    )

    DC_POWER: float = Field(
        ...,
        gt=0,
        le=15000,
        description="Direct current power. Training data ranged from 8.75 to 14471.13.",
    )
    DAILY_YIELD: float = Field(
        ...,
        ge=0,
        le=10000,
        description="Daily yield. Training data ranged from 0 to 9162.86.",
    )
    TOTAL_YIELD: float = Field(
        ...,
        ge=6000000,
        le=8000000,
        description="Total yield. Training data ranged from 6183645 to 7846821.",
    )

    @field_validator("DC_POWER", "DAILY_YIELD", "TOTAL_YIELD")
    @classmethod
    def validate_finite_numbers(cls, value: float) -> float:
        if not math.isfinite(value):
            raise ValueError("Each input value must be a finite number.")
        return value

    @model_validator(mode="after")
    def validate_yield_order(self) -> "PredictionRequest":
        if self.TOTAL_YIELD <= self.DAILY_YIELD:
            raise ValueError("TOTAL_YIELD must be greater than DAILY_YIELD.")
        return self


class PredictionResponse(BaseModel):
    predicted_AC_POWER: float
    best_model_name: str
    feature_order: list[str]


class TrainingRecord(PredictionRequest):
    AC_POWER: float = Field(
        ...,
        ge=0,
        le=1500,
        description="Observed AC power target used when retraining the supervised model.",
    )


class StreamRetrainRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "append_to_existing": True,
                "records": [
                    {
                        "DC_POWER": 1200.0,
                        "DAILY_YIELD": 4100.0,
                        "TOTAL_YIELD": 7055000.0,
                        "AC_POWER": 119.5,
                    }
                ],
            }
        }
    )

    append_to_existing: bool = True
    records: list[TrainingRecord] = Field(
        ...,
        min_length=1,
        description="A batch of labeled records used to update the deployed model.",
    )


class RetrainResponse(BaseModel):
    status: str
    best_model_name: str
    rows_used: int
    training_dataset: str
    rmse_by_model: dict[str, float]
    selected_features: list[str]
    trained_at_utc: str


class HealthResponse(BaseModel):
    status: str
    best_model_name: str
    selected_features: list[str]
    training_dataset: str
    trained_at_utc: Optional[str] = None
    rmse_by_model: dict[str, float]


async def _read_uploaded_csv(file: UploadFile) -> pd.DataFrame:
    if not file.filename:
        raise HTTPException(status_code=400, detail="Please provide a CSV file.")

    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported.")

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="The uploaded CSV file is empty.")

    try:
        return pd.read_csv(io.BytesIO(file_bytes))
    except Exception as exc:  # pragma: no cover - defensive parsing path
        raise HTTPException(status_code=400, detail=f"Unable to parse CSV file: {exc}") from exc


def _build_retrain_response(summary) -> RetrainResponse:
    return RetrainResponse(
        status="retrained",
        best_model_name=summary.best_model_name,
        rows_used=summary.rows_used,
        training_dataset=summary.source_dataset,
        rmse_by_model=summary.rmse_by_model,
        selected_features=summary.selected_features,
        trained_at_utc=summary.trained_at_utc,
    )


@app.get("/", include_in_schema=False)
def root() -> dict[str, str]:
    return {
        "message": "Solar AC Power Prediction API",
        "swagger_ui": "/docs",
    }


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    with service_lock:
        status = service.status()

    return HealthResponse(status="ok", **status)


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest) -> PredictionResponse:
    try:
        with service_lock:
            prediction = service.predict(request.model_dump())
            status = service.status()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - defensive runtime path
        raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc

    return PredictionResponse(
        predicted_AC_POWER=round(prediction, 4),
        best_model_name=status["best_model_name"],
        feature_order=FEATURES,
    )


@app.post("/retrain", response_model=RetrainResponse)
async def retrain(
    file: Optional[UploadFile] = File(default=None),
    append_to_existing: bool = Form(default=True),
) -> RetrainResponse:
    new_training_df = await _read_uploaded_csv(file) if file is not None else None

    try:
        with service_lock:
            summary = service.retrain(
                new_training_df=new_training_df,
                append_to_existing=append_to_existing,
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - defensive runtime path
        raise HTTPException(status_code=500, detail=f"Retraining failed: {exc}") from exc

    return _build_retrain_response(summary)


@app.post("/retrain/stream", response_model=RetrainResponse)
def retrain_from_stream(request: StreamRetrainRequest) -> RetrainResponse:
    records_frame = pd.DataFrame([record.model_dump() for record in request.records])

    try:
        with service_lock:
            summary = service.retrain(
                new_training_df=records_frame,
                append_to_existing=request.append_to_existing,
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - defensive runtime path
        raise HTTPException(status_code=500, detail=f"Retraining failed: {exc}") from exc

    return _build_retrain_response(summary)
