from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeRegressor

FEATURES = ["DC_POWER", "DAILY_YIELD", "TOTAL_YIELD"]
TARGET = "AC_POWER"
REQUIRED_COLUMNS = FEATURES + [TARGET]

BASE_DIR = Path(__file__).resolve().parent
LINEAR_REGRESSION_DIR = BASE_DIR.parent / "linear_regression"
ARTIFACTS_DIR = BASE_DIR / "artifacts"
DEFAULT_DATASET_PATH = LINEAR_REGRESSION_DIR / "Plant_1_Generation_Data.csv"
ACTIVE_DATASET_PATH = ARTIFACTS_DIR / "active_training_data.csv"
MODEL_PATH = ARTIFACTS_DIR / "best_model.joblib"
SCALER_PATH = ARTIFACTS_DIR / "scaler.joblib"
FEATURES_PATH = ARTIFACTS_DIR / "features.joblib"
METRICS_PATH = ARTIFACTS_DIR / "metrics.json"


@dataclass
class TrainingSummary:
    best_model_name: str
    rows_used: int
    source_dataset: str
    rmse_by_model: dict[str, float]
    trained_at_utc: str
    selected_features: list[str]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _build_models() -> dict[str, Any]:
    return {
        "Linear Regression": LinearRegression(),
        "Decision Tree": DecisionTreeRegressor(max_depth=8, random_state=42),
        "Random Forest": RandomForestRegressor(
            n_estimators=50,
            max_depth=8,
            random_state=42,
        ),
    }


def _prepare_training_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    missing_columns = [column for column in REQUIRED_COLUMNS if column not in df.columns]
    if missing_columns:
        missing_text = ", ".join(missing_columns)
        raise ValueError(
            f"Training data is missing required column(s): {missing_text}. "
            f"Expected at least: {', '.join(REQUIRED_COLUMNS)}."
        )

    working_df = df.copy()

    for column in REQUIRED_COLUMNS:
        working_df[column] = pd.to_numeric(working_df[column], errors="coerce")

    working_df = working_df.dropna(subset=REQUIRED_COLUMNS)
    working_df = working_df[working_df["DC_POWER"] > 0].copy()

    if working_df.empty:
        raise ValueError(
            "No usable training rows remain after converting numeric columns and "
            "filtering to DC_POWER > 0."
        )

    if len(working_df) < 50:
        raise ValueError(
            "At least 50 valid rows are required to retrain the model reliably."
        )

    return working_df


class ModelService:
    def __init__(self) -> None:
        self.model: Any | None = None
        self.scaler: StandardScaler | None = None
        self.features: list[str] = FEATURES.copy()
        self.metadata: dict[str, Any] = {}

    def ensure_ready(self) -> None:
        if MODEL_PATH.exists() and SCALER_PATH.exists() and FEATURES_PATH.exists():
            self._load_artifacts()
            return

        self.retrain()

    def predict(self, values: dict[str, float]) -> float:
        self.ensure_ready()

        if self.model is None or self.scaler is None:
            raise ValueError("The model is not loaded.")

        input_frame = pd.DataFrame([values], columns=self.features)
        scaled_values = self.scaler.transform(input_frame)
        prediction = self.model.predict(scaled_values)[0]
        return float(prediction)

    def retrain(
        self,
        new_training_df: pd.DataFrame | None = None,
        append_to_existing: bool = True,
    ) -> TrainingSummary:
        if new_training_df is None:
            training_dataset_path = self._get_training_dataset_path()
            raw_df = pd.read_csv(training_dataset_path)
        else:
            raw_df = self._merge_training_data(
                new_training_df=new_training_df,
                append_to_existing=append_to_existing,
            )
            training_dataset_path = ACTIVE_DATASET_PATH

        prepared_df = _prepare_training_dataframe(raw_df)
        summary = self._train_and_persist(
            prepared_df=prepared_df,
            source_dataset=training_dataset_path,
        )
        self._load_artifacts()
        return summary

    def status(self) -> dict[str, Any]:
        self.ensure_ready()
        return {
            "best_model_name": self.metadata.get("best_model_name", "unknown"),
            "selected_features": self.features,
            "training_dataset": self.metadata.get(
                "source_dataset",
                str(self._get_training_dataset_path()),
            ),
            "trained_at_utc": self.metadata.get("trained_at_utc"),
            "rmse_by_model": self.metadata.get("rmse_by_model", {}),
        }

    def _get_training_dataset_path(self) -> Path:
        if ACTIVE_DATASET_PATH.exists():
            return ACTIVE_DATASET_PATH
        return DEFAULT_DATASET_PATH

    def _merge_training_data(
        self,
        new_training_df: pd.DataFrame,
        append_to_existing: bool,
    ) -> pd.DataFrame:
        if append_to_existing:
            current_df = pd.read_csv(self._get_training_dataset_path())
            merged_df = pd.concat([current_df, new_training_df], ignore_index=True, sort=False)
        else:
            merged_df = new_training_df.copy()

        ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
        merged_df.to_csv(ACTIVE_DATASET_PATH, index=False)
        return merged_df

    def _load_artifacts(self) -> None:
        self.model = joblib.load(MODEL_PATH)
        self.scaler = joblib.load(SCALER_PATH)
        self.features = list(joblib.load(FEATURES_PATH))

        if METRICS_PATH.exists():
            self.metadata = json.loads(METRICS_PATH.read_text())
        else:
            self.metadata = {}

    def _train_and_persist(
        self,
        prepared_df: pd.DataFrame,
        source_dataset: Path,
    ) -> TrainingSummary:
        X = prepared_df[FEATURES]
        y = prepared_df[TARGET]

        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=42,
        )

        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)

        models = _build_models()
        rmse_by_model: dict[str, float] = {}

        for model_name, model in models.items():
            model.fit(X_train_scaled, y_train)
            predictions = model.predict(X_test_scaled)
            rmse = mean_squared_error(y_test, predictions, squared=False)
            rmse_by_model[model_name] = float(rmse)

        best_model_name = min(rmse_by_model, key=rmse_by_model.get)
        best_model = models[best_model_name]

        summary = TrainingSummary(
            best_model_name=best_model_name,
            rows_used=len(prepared_df),
            source_dataset=str(source_dataset),
            rmse_by_model={name: round(value, 4) for name, value in rmse_by_model.items()},
            trained_at_utc=datetime.now(timezone.utc).isoformat(),
            selected_features=FEATURES.copy(),
        )

        ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
        joblib.dump(best_model, MODEL_PATH, compress=3)
        joblib.dump(scaler, SCALER_PATH, compress=3)
        joblib.dump(FEATURES, FEATURES_PATH)
        METRICS_PATH.write_text(json.dumps(summary.to_dict(), indent=2))

        return summary
