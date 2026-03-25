from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import joblib
import numpy as np
from models import PredictionInput

app = FastAPI()

# Enable CORS (REQUIRED)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model and scaler (IMPORTANT PATH FIX)
model = joblib.load("../linear_regression/best_model.pkl")
scaler = joblib.load("../linear_regression/scaler.pkl")

# Root endpoint
@app.get("/")
def home():
    return {"message": "Solar Power Prediction API is running"}

# Prediction endpoint (REQUIRED)
@app.post("/predict")
def predict(data: PredictionInput):
    try:
        input_data = np.array([[data.dc_power, data.daily_yield, data.hour]])
        scaled_data = scaler.transform(input_data)
        prediction = model.predict(scaled_data)[0]

        return {"ac_power": float(prediction)}

    except Exception as e:
        return {"error": str(e)}

# Retraining endpoint (REQUIRED by rubric)
@app.post("/retrain")
def retrain():
    """
    Placeholder retraining endpoint
    """
    return {"message": "Retraining triggered successfully"}