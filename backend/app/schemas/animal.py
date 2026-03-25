from pydantic import BaseModel
from typing import Any


class AnimalCreateRequest(BaseModel):
    species: str
    identification_tag: str | None = None
    breed: str = ""
    sex: str = "female"
    sex_condition: str | None = None
    color: str = ""
    distinguishing_marks: str | None = None
    age_years: float = 0
    height_cm: float | None = None
    milk_yield_ltr: float | None = None
    market_value: float = 0
    sum_insured: float = 0
    body_photos: list[str] = []


class AnimalUpdateRequest(BaseModel):
    identification_tag: str | None = None
    breed: str | None = None
    sex: str | None = None
    sex_condition: str | None = None
    color: str | None = None
    distinguishing_marks: str | None = None
    age_years: float | None = None
    height_cm: float | None = None
    milk_yield_ltr: float | None = None
    market_value: float | None = None
    sum_insured: float | None = None


class AnimalResponse(BaseModel):
    id: str
    unique_id: str
    user_id: str
    species: str
    identification_tag: str | None = None
    breed: str
    sex: str
    sex_condition: str | None = None
    color: str
    distinguishing_marks: str | None = None
    age_years: float
    height_cm: float | None = None
    milk_yield_ltr: float | None = None
    muzzle_id: str | None = None
    muzzle_images: list[Any] = []
    health_score: int | None = None
    health_risk_category: str | None = None
    body_photos: list[Any] = []
    market_value: float
    sum_insured: float
    created_at: str | None = None

    class Config:
        from_attributes = True
