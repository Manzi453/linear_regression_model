from pydantic import BaseModel, Field

class PredictionInput(BaseModel):
    dc_power: float = Field(..., gt=0, lt=100000, description="DC power output from solar panels")
    daily_yield: float = Field(..., gt=0, lt=1000000, description="Daily energy yield")
    hour: int = Field(..., ge=0, le=23, description="Hour of the day (0-23)")


class RetrainResponse(BaseModel):
    message: str
    success: bool = True
    metrics: dict = None


class PredictionResponse(BaseModel):
    predicted_ac_power: float
    confidence_score: float = None