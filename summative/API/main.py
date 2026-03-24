from fastapi import FastAPI, HTTPException, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import joblib
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error
import os
from models import PredictionRequest, PredictionResponse, RetrainResponse
from typing import List

app = FastAPI(title="Solar Power Prediction API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = "../linear_regression/best_model.pkl"
SCALER_PATH = "../linear_regression/scaler.pkl"
FEATURES_PATH = "../linear_regression/features.pkl"

@app.post("/predict/", response_model=PredictionResponse)
async def predict_ac_power(request: PredictionRequest):
    try:
        # Load model and scaler
        model = joblib.load(MODEL_PATH)
        scaler = joblib.load(SCALER_PATH)
        features = joblib.load(FEATURES_PATH)
        
        # Create input DataFrame
        input_df = pd.DataFrame([request.dict()], columns=features)
        input_scaled = scaler.transform(input_df)
        
        # Predict
        prediction = model.predict(input_scaled)[0]
        
        return PredictionResponse(ac_power=float(prediction))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/retrain/", response_model=RetrainResponse)
async def retrain_model(file: UploadFile = File(...)):
    try:
        # Save uploaded file temporarily
        temp_path = "temp_data.csv"
        with open(temp_path, "wb") as f:
            f.write(await file.read())
        
        # Load and preprocess data (same as notebook)
        df = pd.read_csv(temp_path)
        df = df[df['DC_POWER'] > 0]
        df['DATE_TIME'] = pd.to_datetime(df['DATE_TIME'])
        df['hour'] = df['DATE_TIME'].dt.hour
        
        features = ['DC_POWER', 'DAILY_YIELD', 'hour']
        X = df[features]
        y = df['AC_POWER']
        
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        # Train RandomForest (best from notebook)
        model = RandomForestRegressor(random_state=42)
        model.fit(X_train_scaled, y_train)
        
        y_pred = model.predict(X_test_scaled)
        rmse = np.sqrt(mean_squared_error(y_test, y_pred))
        
        # Save models
        joblib.dump(model, MODEL_PATH)
        joblib.dump(scaler, SCALER_PATH)
        joblib.dump(features, FEATURES_PATH)
        
        os.remove(temp_path)
        
        return RetrainResponse(status="success", message="Model retrained successfully", new_rmse=float(rmse))
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {"message": "Solar Power Prediction API is running. Visit /docs for Swagger UI."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

