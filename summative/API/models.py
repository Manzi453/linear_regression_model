from pydantic import BaseModel, Field
from typing import Optional

class PredictionInput(BaseModel):
    dc_power: float = Field(..., gt=0, lt=100000, description="DC power output from solar panels (Watts)")
    daily_yield: float = Field(..., gt=0, lt=1000000, description="Daily energy yield (kWh)")
    hour: int = Field(..., ge=0, le=23, description="Hour of the day (0-23)")

class PredictionResponse(BaseModel):
    predicted_ac_power: float = Field(..., description="Predicted AC power output (kW)")
    confidence_score: Optional[float] = Field(None, description="Confidence score of prediction")

class RetrainResponse(BaseModel):
    message: str = Field(..., description="Status message")
    success: bool = Field(..., description="Whether retraining was successful")
    metrics: Optional[dict] = Field(None, description="Model performance metrics after retraining")