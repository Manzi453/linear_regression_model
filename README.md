# Solar Power Plant Energy Forecasting Mission

**Mission**: Optimize renewable energy grid integration by accurately predicting solar power plant output for better energy planning and distribution.

**Problem**: Forecast AC_POWER generation across 21 inverters using time-based features, weather proxies, and yield data to minimize grid imbalances.

**Dataset**: Plant_1_Generation_Data.csv from Kaggle (Solar Power Generation Data). 68,784 hourly records from 2020 (Plant ID 4135001, 21 inverters). Columns: DATE_TIME, PLANT_ID, SOURCE_KEY, DC_POWER, AC_POWER, DAILY_YIELD, TOTAL_YIELD. Rich time-series data for multivariate regression.

**Visualizations**: Correlation heatmap, feature distributions (histograms), AC_POWER vs time/extracted hour scatterplots in notebook.

