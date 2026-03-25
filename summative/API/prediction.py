import os
import joblib
import pickle
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import logging

from models import PredictionInput, PredictionResponse, RetrainResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 1. Define BASE_DIR first
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 2. Define the FastAPI instance
app = FastAPI(
    title="Solar Power Prediction API",
    description="API for predicting AC power output from solar panels based on DC power, daily yield, and hour",
    version="1.0.0"
)

# Enable CORS (REQUIRED)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. Load the Model and Scaler with fallback mechanisms
model_path = os.path.join(BASE_DIR, "best_model.pkl")
scaler_path = os.path.join(BASE_DIR, "scaler.pkl")

def load_model_with_fallback(filepath):
    """Load model with multiple methods for better compatibility"""
    if not os.path.exists(filepath):
        logger.error(f"File not found: {filepath}")
        raise FileNotFoundError(f"Model file not found: {filepath}")
    
    # Method 1: Try joblib first
    try:
        logger.info(f"Loading model with joblib from {filepath}")
        return joblib.load(filepath)
    except Exception as e:
        logger.warning(f"Joblib loading failed: {e}")
    
    # Method 2: Try pickle
    try:
        logger.info("Attempting to load with pickle...")
        with open(filepath, 'rb') as f:
            return pickle.load(f)
    except Exception as e:
        logger.warning(f"Pickle loading failed: {e}")
    
    # Method 3: Try with explicit encoding
    try:
        logger.info("Attempting to load with pickle (latin1 encoding)...")
        with open(filepath, 'rb') as f:
            return pickle.load(f, encoding='latin1')
    except Exception as e:
        logger.error(f"All loading methods failed for {filepath}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load model from {filepath}"
        )

try:
    model = load_model_with_fallback(model_path)
    scaler = load_model_with_fallback(scaler_path)
    logger.info("Model and scaler loaded successfully")
except Exception as e:
    logger.error(f"Error loading models: {e}")
    raise

# 4. Root endpoint
@app.get("/")
async def read_root():
    return {
        "message": "Solar Power Prediction API is running",
        "docs": "/docs",
        "redoc": "/redoc",
        "status": "active"
    }

# 5. Prediction Endpoint (POST request)
@app.post("/predict", response_model=PredictionResponse)
async def predict(data: PredictionInput):
    """Predict AC power based on DC power, daily yield, and hour"""
    try:
        # Validate input data
        input_data = np.array([[data.dc_power, data.daily_yield, data.hour]])
        
        # Check for NaN or infinite values
        if np.any(np.isnan(input_data)) or np.any(np.isinf(input_data)):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Input contains invalid values (NaN or infinite)"
            )
        
        # Scale the input data
        scaled_data = scaler.transform(input_data)
        
        # Make prediction
        prediction = model.predict(scaled_data)
        
        # Return prediction
        return {
            "predicted_ac_power": round(float(prediction[0]), 2),
            "confidence_score": None  # Add confidence score if your model supports it
        }
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction failed: {str(e)}"
        )

# 6. Health Check Endpoint
@app.get("/health")
async def health_check():
    """Check if the API is healthy and models are loaded"""
    try:
        return {
            "status": "healthy",
            "model_loaded": model is not None,
            "scaler_loaded": scaler is not None,
            "python_version": "3.9.6"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Health check failed: {str(e)}"
        )

# 7. Retraining Endpoint
@app.post("/retrain", response_model=RetrainResponse)
async def retrain():
    """Trigger model retraining (placeholder implementation)"""
    try:
        # Add your retraining logic here
        logger.info("Retraining endpoint called")
        return RetrainResponse(
            message="Model retraining triggered successfully",
            success=True,
            metrics={"status": "placeholder"}
        )
    except Exception as e:
        logger.error(f"Retraining error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Retraining failed: {str(e)}"
        )

# 8. Batch Prediction Endpoint (Optional)
@app.post("/predict-batch")
async def predict_batch(data_list: list[PredictionInput]):
    """Make predictions for multiple inputs at once"""
    try:
        predictions = []
        for data in data_list:
            input_data = np.array([[data.dc_power, data.daily_yield, data.hour]])
            scaled_data = scaler.transform(input_data)
            prediction = model.predict(scaled_data)
            predictions.append(round(float(prediction[0]), 2))
        
        return {"predictions": predictions}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch prediction failed: {str(e)}"
        )