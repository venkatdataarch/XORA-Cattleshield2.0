from pydantic import BaseModel
from typing import Any


class ProposalCreateRequest(BaseModel):
    animal_id: str
    form_data: dict[str, Any] = {}
    sum_insured: float = 0


class ProposalUpdateRequest(BaseModel):
    form_data: dict[str, Any] | None = None
    status: str | None = None


class VetDecisionRequest(BaseModel):
    decision: str  # "approved" or "rejected"
    reason: str | None = None


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

    class Config:
        from_attributes = True
