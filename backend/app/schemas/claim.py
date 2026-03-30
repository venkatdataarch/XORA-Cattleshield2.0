from pydantic import BaseModel, model_validator
from typing import Any


class ClaimCreateRequest(BaseModel):
    policy_id: str
    type: str  # death, injury, disease
    form_data: dict[str, Any] = {}


class VetClaimDecisionRequest(BaseModel):
    decision: str  # "approved" or "rejected"
    reason: str | None = None
    settlement_amount: float | None = None

    @model_validator(mode="after")
    def require_reason_on_reject(self):
        if self.decision == "rejected" and not self.reason:
            raise ValueError("Reason is required when rejecting a claim")
        return self


class ClaimResponse(BaseModel):
    id: str
    policy_id: str
    animal_id: str
    claim_number: str
    type: str
    form_data: dict[str, Any] = {}
    evidence_media: list[Any] = []
    ai_muzzle_match_score: float | None = None
    ai_match_result: str | None = None
    status: str
    settlement_amount: float | None = None
    settled_at: str | None = None
    rejection_reason: str | None = None
    animal_name: str = ""
    policy_number: str = ""
    created_at: str | None = None

    class Config:
        from_attributes = True
