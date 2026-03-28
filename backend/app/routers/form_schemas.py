from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.form_schema import FormSchema
from ..schemas.form_schema import FormSchemaResponse

router = APIRouter(prefix="/form-schema", tags=["Form Schemas"])


@router.get("/{form_type}", response_model=FormSchemaResponse)
async def get_form_schema(
    form_type: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(FormSchema).where(FormSchema.form_type == form_type)
    )
    schema = result.scalar_one_or_none()
    if not schema:
        raise HTTPException(status_code=404, detail=f"Form schema '{form_type}' not found")

    return FormSchemaResponse(
        id=str(schema.id),
        form_type=schema.form_type,
        version=schema.version,
        title=schema.title,
        schema_json=schema.schema_json or {},
        animal_types=schema.animal_types or [],
        created_at=schema.created_at.isoformat() if schema.created_at else None,
    )
