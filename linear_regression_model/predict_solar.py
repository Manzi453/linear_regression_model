#!/usr/bin/env python3
"""
Solar Power Prediction CLI using trained RandomForest model.
Usage: python predict_solar.py --dc_power 1000 --daily_yield 500 --hour 12
"""
import argparse
import joblib
import pandas as pd
import numpy as np

def predict_ac_power(dc_power, daily_yield, hour):
    """Predict AC_POWER using saved model."""
    try:
        model = joblib.load('best_model.pkl')
        scaler = joblib.load('scaler.pkl')
        features = joblib.load('features.pkl')
        
        input_data = pd.DataFrame({
            features[0]: [dc_power],
            features[1]: [daily_yield],
            features[2]: [hour]
        })
        
        input_scaled = scaler.transform(input_data)
        prediction = model.predict(input_scaled)[0]
        return prediction
    except FileNotFoundError as e:
        print(f"Model files not found: {e}")
        print("Run the notebook first to train and save models.")
        return None
    except Exception as e:
        print(f"Prediction error: {e}")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Predict solar AC power.")
    parser.add_argument("--dc_power", type=float, required=True, help="DC_POWER value")
    parser.add_argument("--daily_yield", type=float, required=True, help="DAILY_YIELD value")
    parser.add_argument("--hour", type=int, required=True, help="Hour of day (0-23)")
    
    args = parser.parse_args()
    
    pred = predict_ac_power(args.dc_power, args.daily_yield, args.hour)
    if pred is not None:
        print(f"Predicted AC_POWER: {pred:.4f}")
    
