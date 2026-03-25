from pydantic import BaseModel, Field

class PredictionInput(BaseModel):
    dc_power: float = Field(..., gt=0, lt=100000)
    daily_yield: float = Field(..., gt=0, lt=1000000)
    hour: int = Field(..., ge=0, le=23)