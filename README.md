# Linear Regression Model - Solar Power Prediction

## Mission & Problem
Predict AC power output for solar plant optimization using DC_POWER, DAILY_YIELD, TOTAL_YIELD. Dataset: Plant_1_Generation_Data.csv (Kaggle-like solar inverter data, 68k+ rows).

## Task 1: Model Training
`summative/linear_regression/multivariate.ipynb`: compares Linear Regression, Decision Tree, and Random Forest on the solar dataset. The API retrains and stores its deployment artifacts in `summative/API/artifacts/`.

## Task 2: API
Code lives in `summative/API/` and exposes the trained solar power model through FastAPI.

**Swagger UI (local):** `http://127.0.0.1:8000/docs`

**Swagger UI (after Render deploy):** `https://<your-render-service>.onrender.com/docs`

**Endpoints:**
- `GET /health`: confirms the API is running and shows the active model and RMSE values
- `POST /predict`: accepts `DC_POWER`, `DAILY_YIELD`, and `TOTAL_YIELD` and returns predicted `AC_POWER`
- `POST /retrain`: retrains on the current dataset or an uploaded CSV file
- `POST /retrain/stream`: retrains from streamed JSON records with labels

**Local Test:**
```
cd summative/API
pip install -r requirements.txt
python3 -m uvicorn main:app --reload

curl -X POST "http://127.0.0.1:8000/predict" \
  -H "Content-Type: application/json" \
  -d '{"DC_POWER":1000,"DAILY_YIELD":5000,"TOTAL_YIELD":7000000}'
```

**Validation and CORS:**
- Pydantic enforces numeric data types and realistic ranges taken from the solar dataset
- `TOTAL_YIELD` must be greater than `DAILY_YIELD`
- CORS is configured with explicit origins, methods, headers, and credentials
- Extra origins can be set with `ALLOWED_ORIGINS`, and Render can inject `RENDER_EXTERNAL_URL`

**Render Deploy:**
1. Push repo to GitHub
2. On Render, create a new Web Service and set the root directory to `summative/API`
3. Build command: `pip install -r requirements.txt`
4. Start command: `gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:$PORT`
5. Add `ALLOWED_ORIGINS` with the Flutter/web origins you want to allow
6. After deployment, replace the placeholder URL above with your real `/docs` URL

**API files:**
- `summative/API/prediction.py`
- `summative/API/model_service.py`
- `summative/API/main.py`
- `summative/API/requirements.txt`

**Task 3:** Flutter app at summative/FlutterApp/solar_app/
