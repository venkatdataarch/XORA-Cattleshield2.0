from pydantic import BaseModel, model_validator
from typing import Any


class ProposalCreateRequest(BaseModel):
    animal_id: str
    form_data: dict[str, Any] = {}
    sum_insured: float = 0


class ProposalUpdateRequest(BaseModel):
    form_data: dict[str, Any] | None = None


class VetDecisionRequest(BaseModel):
    decision: str  # "approved" or "rejected"
    reason: str | None = None

    @model_validator(mode="after")
    def require_reason_on_reject(self):
        if self.decision == "rejected" and not self.reason:
            raise ValueError("Reason is required when rejecting a proposal")
        return self


class AnimalDetail(BaseModel):
    id: str = ""
    unique_id: str = ""
    species: str = ""
    breed: str = ""
    sex: str = ""
    sex_condition: str | None = None
    color: str = ""
    age_years: float | None = None
    height_cm: float | None = None
    milk_yield_ltr: float | None = None
    market_value: float | None = None
    distinguishing_marks: str | None = None
    identification_tag: str | None = None
    health_score: int | None = None
    health_risk_category: str | None = None
    muzzle_images: list[Any] = []
    body_photos: list[Any] = []

    class Config:
        from_attributes = True


class FarmerDetail(BaseModel):
    id: str = ""
    name: str = ""
    phone: str = ""
    village: str | None = None
    district: str | None = None
    state: str | None = None
    aadhaar_number: str | None = None
    father_or_husband_name: str | None = None
    occupation: str | None = None

    class Config:
        from_attributes = True


class ProposalResponse(BaseModel):
    id: str
    animal_id: str
    farmer_id: str
    form_data: dict[str, Any] = {}
    form_schema_version: str = "1.0"
    status: str
    rejection_reason: str | None = None
    uiic_reference: str | None = None
    sum_insured: float
    premium: float | None = None
    animal_name: str = ""
    animal_species: str = ""
    submitted_at: str | None = None
    vet_reviewed_at: str | None = None
    uiic_sent_at: str | None = None
    created_at: str | None = None
    animal: AnimalDetail | None = None
    farmer: FarmerDetail | None = None

    class Config:
        from_attributes = True
