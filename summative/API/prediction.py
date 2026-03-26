from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import numpy as np

from fastapi.middleware.cors import CORSMiddleware

from model_loader import load_model, load_scaler

app = FastAPI(title="Solar Power Prediction API")

# ✅ Proper CORS config (NOT *)
origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["*"],
)

# Load model + scaler
model = load_model()
scaler = load_scaler()

# ✅ Input schema with validation
class PredictionInput(BaseModel):
    DC_POWER: float = Field(..., ge=0, le=100000)
    DAILY_YIELD: float = Field(..., ge=0)
    TOTAL_YIELD: float = Field(..., ge=0)

# Root endpoint
@app.get("/")
def home():
    return {"message": "API is running"}

# ✅ Prediction endpoint
@app.post("/predict")
def predict(data: PredictionInput):
    try:
        features = np.array([
            data.DC_POWER,
            data.DAILY_YIELD,
            data.TOTAL_YIELD
        ]).reshape(1, -1)

        # Apply scaler if exists
        if scaler:
            features = scaler.transform(features)

        prediction = model.predict(features)

        return {
            "prediction": float(prediction[0])
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

        from retrain import router as retrain_router

app.include_router(retrain_router)