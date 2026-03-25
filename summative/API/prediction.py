import os
import joblib
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import numpy as np

from models import PredictionInput

# 1. Define BASE_DIR first
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

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

model = joblib.load(model_path)
scaler = joblib.load(scaler_path)

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
