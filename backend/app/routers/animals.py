import uuid
import random

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.proposal import Proposal
from ..models.user import User
from ..schemas.animal import AnimalCreateRequest, AnimalUpdateRequest, AnimalResponse
from ..middleware.auth import get_current_user
from ..utils.file_storage import save_upload
from .fraud import create_fraud_alert

router = APIRouter(prefix="/animals", tags=["Animals"])


def _animal_response(animal: Animal) -> AnimalResponse:
    return AnimalResponse(
        id=str(animal.id),
        unique_id=animal.unique_id,
        user_id=str(animal.user_id),
        species=animal.species,
        identification_tag=animal.identification_tag,
        breed=animal.breed,
        sex=animal.sex,
        sex_condition=animal.sex_condition,
        color=animal.color,
        distinguishing_marks=animal.distinguishing_marks,
        age_years=animal.age_years,
        height_cm=animal.height_cm,
        milk_yield_ltr=animal.milk_yield_ltr,
        muzzle_id=animal.muzzle_id,
        muzzle_images=animal.muzzle_images or [],
        health_score=animal.health_score,
        health_risk_category=animal.health_risk_category,
        body_photos=animal.body_photos or [],
        market_value=animal.market_value,
        sum_insured=animal.sum_insured,
        created_at=animal.created_at.isoformat() if animal.created_at else None,
    )


def _generate_unique_id(species: str) -> str:
    prefix = "UCID" if species in ("cow", "buffalo") else "MUID"
    return f"{prefix}-{uuid.uuid4().hex[:8].upper()}"


@router.get("/", response_model=list[AnimalResponse])
async def list_animals(
    species: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = select(Animal).where(Animal.user_id == user.id)
    if species:
        query = query.where(Animal.species == species)
    query = query.order_by(Animal.created_at.desc())
    result = await db.execute(query)
    animals = result.scalars().all()
    return [_animal_response(a) for a in animals]


@router.post("/", response_model=AnimalResponse, status_code=201)
async def register_animal(
    req: AnimalCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    animal = Animal(
        unique_id=_generate_unique_id(req.species),
        user_id=user.id,
        species=req.species,
        identification_tag=req.identification_tag,
        breed=req.breed,
        sex=req.sex,
        sex_condition=req.sex_condition,
        color=req.color,
        distinguishing_marks=req.distinguishing_marks,
        age_years=req.age_years,
        height_cm=req.height_cm,
        milk_yield_ltr=req.milk_yield_ltr,
        market_value=req.market_value,
        sum_insured=req.sum_insured,
        body_photos=req.body_photos,
        muzzle_images=[],
        health_score=random.randint(75, 95),
        health_risk_category="low" if random.random() > 0.3 else "medium",
    )
    db.add(animal)
    await db.flush()

    # Auto-create proposal for vet review
    sum_insured = req.sum_insured or req.market_value or 50000.0
    premium = round(sum_insured * 0.04, 2)
    proposal = Proposal(
        animal_id=animal.id,
        farmer_id=user.id,
        status="submitted",
        form_data={
            "animal_type": req.species,
            "breed": req.breed,
            "age": req.age_years,
            "sex": req.sex,
            "color": req.color,
            "distinguishing_marks": req.distinguishing_marks,
            "milk_yield": req.milk_yield_ltr,
            "market_value": req.market_value,
            "identification_tag": req.identification_tag,
        },
        sum_insured=sum_insured,
        premium=premium,
        animal_name=f"{req.breed or req.species} - {animal.unique_id}",
        animal_species=req.species,
    )
    db.add(proposal)
    await db.flush()

    return _animal_response(animal)


@router.get("/{animal_id}", response_model=AnimalResponse)
async def get_animal(
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
    # Ownership check: only the owner or vet/admin can view
    if user.role not in ("vet", "admin") and str(animal.user_id) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to view this animal")
    return _animal_response(animal)


@router.put("/{animal_id}", response_model=AnimalResponse)
async def update_animal(
    animal_id: str,
    req: AnimalUpdateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Animal).where(Animal.id == animal_id, Animal.user_id == user.id)
    )
    animal = result.scalar_one_or_none()
    if not animal:
        raise HTTPException(status_code=404, detail="Animal not found")

    update_data = req.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(animal, key, value)

    await db.flush()
    return _animal_response(animal)


@router.post("/{animal_id}/muzzle-scan")
async def muzzle_scan(
    animal_id: str,
    files: list[UploadFile] = File(default=[]),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Animal).where(Animal.id == animal_id)
    )
    animal = result.scalar_one_or_none()
    if not animal:
        raise HTTPException(status_code=404, detail="Animal not found")

    # Save uploaded images
    image_urls = []
    for f in files:
        url = await save_upload(f, subfolder="muzzle")
        image_urls.append(url)

    # Generate mock muzzle ID
    muzzle_id = f"MZL-{uuid.uuid4().hex[:12].upper()}"

    # --- Duplicate detection (Scope 2d) ---
    # Check if any existing animal has a muzzle_id (simulate biometric match)
    existing = await db.execute(
        select(Animal).where(
            Animal.muzzle_id.isnot(None),
            Animal.id != animal_id,
        )
    )
    existing_animals = existing.scalars().all()
    duplicate_match = None
    for ea in existing_animals:
        # Simulate muzzle comparison — mock similarity score
        similarity = random.uniform(0.3, 1.0)
        if similarity > 0.80:
            duplicate_match = {
                "matched_animal_id": ea.id,
                "matched_unique_id": ea.unique_id,
                "similarity_score": round(similarity * 100, 1),
                "owner_id": ea.user_id,
            }
            # Create fraud alert
            await create_fraud_alert(
                db=db,
                alert_type="duplicate_muzzle",
                risk_level="high",
                description=f"Duplicate muzzle detected: new animal {animal.unique_id} matches existing {ea.unique_id} ({round(similarity * 100, 1)}% similarity)",
                risk_score=similarity * 100,
                user_id=str(user.id),
                animal_id=str(animal_id),
            )
            break

    animal.muzzle_id = muzzle_id
    animal.muzzle_images = image_urls
    await db.flush()

    response = {
        "muzzle_id": muzzle_id,
        "images": image_urls,
        "message": "Muzzle scan processed successfully",
    }
    if duplicate_match:
        response["duplicate_warning"] = duplicate_match
        response["message"] = "WARNING: Possible duplicate animal detected"

    return response
