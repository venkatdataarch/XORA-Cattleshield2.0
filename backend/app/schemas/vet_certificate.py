from pydantic import BaseModel
from typing import Any


class CertificateCreateRequest(BaseModel):
    related_id: str
    type: str  # proposal, claim_death, claim_injury
    form_data: dict[str, Any] = {}


class CertificateResponse(BaseModel):
    id: str
    related_id: str
    type: str
    form_data: dict[str, Any] = {}
    vet_signature_url: str | None = None
    vet_id: str
    created_at: str | None = None

    class Config:
        from_attributes = True
