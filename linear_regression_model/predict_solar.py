#!/usr/bin/env python3
"""
Solar Power Prediction Script using trained model.
Usage: python predict_solar.py --dc_power 1000 --daily_yield 50 --total_yield 10000 --hour 12 --day 15 --month 5 --day_of_week 3
"""
import argparse
import joblib
import sys
import pandas as pd
import numpy as np

def main():
    parser = argparse.ArgumentParser(description='Predict solar AC power output')
    parser.add_argument('--dc_power', type=float, required=True, help='DC_POWER value')
    parser.add_argument('--daily_yield', type=float, required=True, help='DAILY_YIELD value')
    parser.add_argument('--total_yield', type=float, required=True, help='TOTAL_YIELD value')
    parser.add_argument('--hour', type=int, required=True, help='Hour (0-23)')
    parser.add_argument('--day', type=int, required=True, help='Day of month (1-31)')
    parser.add_argument('--month', type=int, required=True, help='Month (1-12)')
    parser.add_argument('--day_of_week', type=int, required=True, help='Day of week (0=Monday)')
    
    args = parser.parse_args()
    
    try:
        # Load model
        model_data = joblib.load('best_solar_model.pkl')
        model = model_data['model']
        scaler = model_data['scaler']
        features = model_data['features']
        
        # Prepare input
        input_data = pd.DataFrame([{
            'DC_POWER': args.dc_power,
            'DAILY_YIELD': args.daily_yield,
            'TOTAL_YIELD': args.total_yield,
            'hour': args.hour,
            'day': args.day,
            'month': args.month,
            'day_of_week': args.day_of_week
        }])
        
        # Scale and predict
        input_scaled = scaler.transform(input_data[features])
        prediction = model.predict(input_scaled)[0]
        
        print(f"Predicted AC_POWER: {prediction:.2f} kW")
        print(f"Input features: {input_data.to_dict('records')[0]}")
        
    except FileNotFoundError:
        print("Error: best_solar_model.pkl not found. Run multivariate.ipynb first.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

