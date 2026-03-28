from pydantic import BaseModel
from typing import Any


class PolicyResponse(BaseModel):
    id: str
    proposal_id: str
    animal_id: str
    policy_number: str
    insured_name: str
    sum_insured: float
    premium: float
    start_date: str
    end_date: str
    animal_name: str = ""
    animal_species: str = ""
    details_json: dict[str, Any] | None = None
    created_at: str | None = None

    class Config:
        from_attributes = True
