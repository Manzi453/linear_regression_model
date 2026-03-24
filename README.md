# Linear Regression Model - Solar Power Prediction

## Task 1: Model Training
- See `summative/linear_regression/multivariate.ipynb`
- Best model: RandomForestRegressor (multivariate: DC_POWER, DAILY_YIELD, hour)
- RMSE: ~17.72
- Saved: `summative/linear_regression/best_model.pkl`, `scaler.pkl`, `features.pkl`

## Task 2: FastAPI Deployment (COMPLETE)
**Local:** 
```
cd summative/API
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```
- Visit http://localhost:8000/docs
- **/predict/**: POST JSON `{"dc_power": 1000, "daily_yield": 500, "hour": 12}` → `{"ac_power": 950.5}`
- **/retrain/**: POST CSV file (same format as training data)

**Deploy:** Push to GitHub → Render Web Service (Python, `uvicorn main:app --host 0.0.0.0 --port $PORT`)

## Features
- Pydantic validation (DC_POWER 0-15000, etc.)
- CORS enabled
- Model retraining endpoint
- Uses trained multivariate model from Task 1
