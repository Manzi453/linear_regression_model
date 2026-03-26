# Linear Regression Model - Solar Power Prediction

## Mission & Problem
Predict AC power output for solar plant optimization using DC_POWER, DAILY_YIELD, TOTAL_YIELD. Dataset: Plant_1_Generation_Data.csv (Kaggle-like solar inverter data, 68k+ rows).

## Task 1: Model Training
`summative/linear_regression/multivariate.ipynb`: RandomForest best (RMSE~17), saved pkl files copied to API/.

## Task 2: API (Deployed on Render)
**Swagger UI:** https://YOUR-RENDER-URL.onrender.com/docs

**Endpoints:**
- POST /predict: `{"DC_POWER":1000,"DAILY_YIELD":5000,"TOTAL_YIELD":6000000}` → `{"AC_POWER":950.5}`
- POST /retrain: Triggers retrain on dataset (reloads model)
- GET /health

**Local Test:**
```
cd summative/API && source venv/bin/activate && pip install -r requirements.txt && uvicorn main:app --reload
curl -X POST "http://localhost:8000/predict" -H "Content-Type: application/json" -d '{"DC_POWER":1000,"DAILY_YIELD":5000,"TOTAL_YIELD":6000000}'
```

**Render Deploy:**
1. Push repo to GitHub
2. render.com → New → Web Service → Connect repo
3. Build: `pip install -r requirements.txt`
4. Start: `gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app`

Rubric: Pydantic constraints, CORS middleware (specific origins), retrain endpoint for new data.

**Task 3:** Flutter app at summative/FlutterApp/solar_app/
