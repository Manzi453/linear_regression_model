import joblib
import numpy as np

# Load saved artifacts
model = joblib.load("best_model.pkl")
scaler = joblib.load("scaler.pkl")

def predict(dc_power, daily_yield, hour):
    """
    Make prediction using trained model
    """
    data = np.array([[dc_power, daily_yield, hour]])
    scaled_data = scaler.transform(data)
    prediction = model.predict(scaled_data)[0]
    return float(prediction)

if __name__ == "__main__":
    result = predict(1000, 500, 12)
    print("Predicted AC Power:", result)