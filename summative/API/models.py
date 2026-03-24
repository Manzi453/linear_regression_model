from pydantic import BaseModel, Field
from typing import Optional

class PredictionRequest(BaseModel):
    dc_power: float = Field(..., ge=0, le=15000, description="DC Power (kW)")
    daily_yield: float = Field(..., ge=0, le=10000, description="Daily Yield (kWh)")
    hour: int = Field(..., ge=0, le=23, description="Hour of day (0-23)")

class PredictionResponse(BaseModel):
    ac_power: float = Field(..., description="Predicted AC Power (kW)")

class RetrainResponse(BaseModel):
    status: str
    message: str
    new_rmse: Optional[float] = None

