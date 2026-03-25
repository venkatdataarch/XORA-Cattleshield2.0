import uuid
import random

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.user import User
from ..middleware.auth import get_current_user

router = APIRouter(prefix="/ai", tags=["AI Services"])


@router.get("/health-score/{animal_id}")
async def get_health_score(
    animal_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Animal).where(Animal.id == animal_id)
    )
    animal = result.scalar_one_or_none()
    if not animal:
        raise HTTPException(status_code=404, detail="Animal not found")

    # Mock AI health scoring
    base_score = random.randint(70, 95)
    age_penalty = min(int(animal.age_years * 2), 15) if animal.age_years > 5 else 0
    score = max(50, base_score - age_penalty)

    if score >= 80:
        risk_category = "low"
        risk_label = "Healthy"
    elif score >= 60:
        risk_category = "medium"
        risk_label = "Moderate Risk"
    else:
        risk_category = "high"
        risk_label = "High Risk"

    # Update animal record
    animal.health_score = score
    animal.health_risk_category = risk_category
    await db.flush()

    observations = []
    if animal.species in ("cow", "buffalo"):
        observations = [
            {"label": "Body Condition", "value": "Good" if score >= 75 else "Fair", "icon": "fitness_center"},
            {"label": "Coat Quality", "value": "Healthy" if score >= 70 else "Dull", "icon": "brush"},
            {"label": "Gait Analysis", "value": "Normal" if score >= 65 else "Slight Limp", "icon": "directions_walk"},
            {"label": "Eye Clarity", "value": "Clear" if score >= 60 else "Cloudy", "icon": "visibility"},
            {"label": "Udder Health", "value": "Normal" if score >= 70 else "Needs Check", "icon": "water_drop"},
        ]
    else:
        observations = [
            {"label": "Body Condition", "value": "Good" if score >= 75 else "Fair", "icon": "fitness_center"},
            {"label": "Hoof Condition", "value": "Healthy" if score >= 70 else "Needs Trim", "icon": "straighten"},
            {"label": "Coat Quality", "value": "Healthy" if score >= 70 else "Dull", "icon": "brush"},
            {"label": "Movement", "value": "Normal" if score >= 65 else "Stiff", "icon": "directions_walk"},
        ]

    return {
        "animal_id": str(animal.id),
        "score": score,
        "risk_category": risk_category,
        "risk_label": risk_label,
        "observations": observations,
        "recommendation": f"Overall health index: {score}/100. {'Animal is in good health.' if score >= 75 else 'Recommend veterinary checkup.'}",
    }
