from fastapi import APIRouter
import pandas as pd
import joblib
import os

from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

router = APIRouter()

BASE_DIR = os.path.dirname(__file__)
MODEL_PATH = os.path.join(BASE_DIR, "best_model.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "scaler.pkl")

@router.post("/retrain")
def retrain():
    try:
        df = pd.read_csv("Plant_1_Generation_Data.csv")

        # Drop irrelevant columns
        df = df.drop(columns=["DATE_TIME", "SOURCE_KEY", "PLANT_ID"], errors="ignore")

        X = df[["DC_POWER", "DAILY_YIELD", "TOTAL_YIELD"]]
        y = df["AC_POWER"]

        # Scaling
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        X_train, X_test, y_train, y_test = train_test_split(
            X_scaled, y, test_size=0.2, random_state=42
        )

        model = LinearRegression()
        model.fit(X_train, y_train)

        # Save updated model
        joblib.dump(model, MODEL_PATH, compress=3)
        joblib.dump(scaler, SCALER_PATH)

        return {"message": "Model retrained successfully"}

    except Exception as e:
        return {"error": str(e)}