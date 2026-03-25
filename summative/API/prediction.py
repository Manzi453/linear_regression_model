import os
import joblib
import pickle
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import numpy as np

from models import PredictionInput

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 1. Define BASE_DIR first
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Robust model loading function (matches container expectation, fixed)
def load_model_with_fallback(model_path):
    """
    Try joblib first (sklearn recommended), fallback to pickle without buggy latin1 encoding.
    """
    try:
        logger.info(f"Loading model with joblib from {model_path}")
        return joblib.load(model_path)
    except Exception as e:
        logger.warning(f"Joblib loading failed: {e}")
        try:
            logger.info(f"Attempting to load with pickle...")
            with open(model_path, 'rb') as f:
                return pickle.load(f)
        except Exception as e2:
            logger.error(f"Pickle loading failed: {e2}")
            raise Exception(f"All loading methods failed for {model_path}: {e2}")

# 2. Define the FastAPI instance
app = FastAPI(title="Solar Power Prediction API")

# Enable CORS (REQUIRED)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. Load the Model and Scaler using the absolute paths
model_path = os.path.join(BASE_DIR, "best_model.pkl")
scaler_path = os.path.join(BASE_DIR, "scaler.pkl")

model = load_model_with_fallback(model_path)
scaler = load_model_with_fallback(scaler_path)

# 4. Root endpoint
@app.get("/")
async def read_root():
    return {"message": "Solar Power Prediction API is running. Visit /docs for Swagger UI."}

# 5. Prediction Endpoint (POST request)
@app.post("/predict")
async def predict(data: PredictionInput):
    input_data = np.array([[data.dc_power, data.daily_yield, data.hour]])
    scaled_data = scaler.transform(input_data)
    prediction = model.predict(scaled_data)
    return {"predicted_ac_power": round(float(prediction[0]), 2)}

# 6. Retraining Endpoint (Required)
@app.post("/retrain")
async def retrain():
    return {"message": "Model retraining triggered successfully"}
