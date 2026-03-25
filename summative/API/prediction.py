import os
import joblib
import logging
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, r2_score

from models import PredictionInput, PredictionResponse, RetrainResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

FEATURE_COLUMNS = ['DC_POWER', 'DAILY_YIELD', 'hour']
TARGET_COLUMN = 'AC_POWER'


def train_and_save_model():
    """Train model from CSV and save best_model.pkl + scaler.pkl"""
    data_path = os.path.join(BASE_DIR, "Plant_1_Generation_Data.csv")
    if not os.path.exists(data_path):
        raise FileNotFoundError(
            f"Training data not found at {data_path}. "
            "Please place Plant_1_Generation_Data.csv next to prediction.py."
        )

    logger.info("Training new model from Plant_1_Generation_Data.csv ...")
    df = pd.read_csv(data_path)
    df['DATE_TIME'] = pd.to_datetime(df['DATE_TIME'])
    df['hour'] = df['DATE_TIME'].dt.hour
    df = df[df['DC_POWER'] > 0].copy()

    X = df[FEATURE_COLUMNS]
    y = df[TARGET_COLUMN]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    scaler_new = StandardScaler()
    X_train_scaled = scaler_new.fit_transform(X_train)
    X_test_scaled = scaler_new.transform(X_test)

    rf = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
    rf.fit(X_train_scaled, y_train)

    y_pred = rf.predict(X_test_scaled)
    rmse = float(np.sqrt(mean_squared_error(y_test, y_pred)))
    r2 = float(r2_score(y_test, y_pred))
    logger.info(f"Trained model — RMSE: {rmse:.4f}, R²: {r2:.4f}")

    model_path = os.path.join(BASE_DIR, "best_model.pkl")
    scaler_path = os.path.join(BASE_DIR, "scaler.pkl")
    joblib.dump(rf, model_path)
    joblib.dump(scaler_new, scaler_path)
    logger.info("Saved best_model.pkl and scaler.pkl")

    return rf, scaler_new, {"rmse": round(rmse, 4), "r2_score": round(r2, 4)}


def load_or_train_model():
    """Load existing model/scaler, or train from scratch if missing/corrupt."""
    model_path = os.path.join(BASE_DIR, "best_model.pkl")
    scaler_path = os.path.join(BASE_DIR, "scaler.pkl")

    if os.path.exists(model_path) and os.path.exists(scaler_path):
        try:
            logger.info(f"Loading model from {model_path}")
            loaded_model = joblib.load(model_path)
            loaded_scaler = joblib.load(scaler_path)
            logger.info("Model and scaler loaded successfully.")
            return loaded_model, loaded_scaler
        except Exception as e:
            logger.warning(f"Could not load existing pkl files ({e}). Retraining ...")

    # Train fresh
    loaded_model, loaded_scaler, _ = train_and_save_model()
    return loaded_model, loaded_scaler


# ── App setup ──────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Solar Power Prediction API",
    description="Predicts AC power output from solar panel readings.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://solar-power-prediction.onrender.com"],  # replace with your Flutter web domain, or keep * for dev
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Load / train at startup
model, scaler = load_or_train_model()


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.get("/")
async def read_root():
    return {
        "message": "Solar Power Prediction API is running",
        "status": "active",
        "docs": "/docs",
        "redoc": "/redoc",
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "scaler_loaded": scaler is not None,
    }


@app.post("/predict", response_model=PredictionResponse)
async def predict(data: PredictionInput):
    """Predict AC power output given DC power, daily yield, and hour."""
    try:
        input_array = np.array([[data.dc_power, data.daily_yield, data.hour]])
        scaled = scaler.transform(input_array)
        prediction = float(model.predict(scaled)[0])

        max_possible = 1500.0
        confidence_score = round(min(0.95, prediction / max_possible), 3)

        return PredictionResponse(
            predicted_ac_power=round(prediction, 2),
            confidence_score=confidence_score,
        )
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.post("/retrain", response_model=RetrainResponse)
async def retrain():
    """Retrain the model from Plant_1_Generation_Data.csv."""
    global model, scaler
    try:
        model, scaler, metrics = train_and_save_model()
        return RetrainResponse(
            message="Model retrained successfully",
            success=True,
            metrics=metrics,
        )
    except Exception as e:
        logger.error(f"Retraining error: {e}")
        return RetrainResponse(
            message=f"Retraining failed: {str(e)}",
            success=False,
            metrics=None,
        )


@app.get("/model-info")
async def model_info():
    return {
        "model_type": type(model).__name__,
        "features": FEATURE_COLUMNS,
        "target": TARGET_COLUMN,
        "model_loaded": model is not None,
        "scaler_loaded": scaler is not None,
    }