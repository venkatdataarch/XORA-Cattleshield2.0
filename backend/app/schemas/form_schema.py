from pydantic import BaseModel
from typing import Any


class FormSchemaResponse(BaseModel):
    id: str
    form_type: str
    version: str
    title: str
    schema_json: dict[str, Any] = {}
    animal_types: list[str] = []
    created_at: str | None = None

    class Config:
        from_attributes = True
