from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.proposal import Proposal
from ..models.claim import Claim
from ..models.user import User
from ..middleware.auth import get_current_vet
from ..utils.timezone import to_ist

router = APIRouter(prefix="/vet", tags=["Vet"])


@router.get("/pending")
async def get_pending_reviews(
    db: AsyncSession = Depends(get_db),
    vet: User = Depends(get_current_vet),
):
    # Get proposals needing vet review
    prop_result = await db.execute(
        select(Proposal).where(
            Proposal.status.in_(["submitted", "vet_review"])
        ).order_by(Proposal.submitted_at.desc())
    )
    proposals = prop_result.scalars().all()

    # For each proposal, fetch the animal and farmer details
    proposal_list = []
    for p in proposals:
        # Get animal with images
        animal_result = await db.execute(
            select(Animal).where(Animal.id == p.animal_id)
        )
        animal = animal_result.scalar_one_or_none()

        # Get farmer details
        farmer_result = await db.execute(
            select(User).where(User.id == p.farmer_id)
        )
        farmer = farmer_result.scalar_one_or_none()

        proposal_data = {
            "id": str(p.id),
            "animal_id": str(p.animal_id),
            "farmer_id": str(p.farmer_id),
            "status": p.status,
            "sum_insured": p.sum_insured,
            "premium": p.premium,
            "animal_name": p.animal_name,
            "animal_species": p.animal_species,
            "form_data": p.form_data,
            "submitted_at": to_ist(p.submitted_at),
            "created_at": to_ist(p.created_at),
            # Animal details with images
            "animal": None,
            # Farmer details
            "farmer": None,
        }

        if animal:
            proposal_data["animal"] = {
                "id": str(animal.id),
                "unique_id": animal.unique_id,
                "species": animal.species,
                "breed": animal.breed,
                "sex": animal.sex,
                "sex_condition": animal.sex_condition,
                "color": animal.color,
                "distinguishing_marks": animal.distinguishing_marks,
                "age_years": animal.age_years,
                "height_cm": animal.height_cm,
                "milk_yield_ltr": animal.milk_yield_ltr,
                "market_value": animal.market_value,
                "sum_insured": animal.sum_insured,
                "identification_tag": animal.identification_tag,
                "muzzle_id": animal.muzzle_id,
                "muzzle_images": animal.muzzle_images or [],
                "body_photos": animal.body_photos or [],
                "health_score": animal.health_score,
                "health_risk_category": animal.health_risk_category,
            }

        if farmer:
            proposal_data["farmer"] = {
                "id": str(farmer.id),
                "name": farmer.name,
                "phone": farmer.phone,
                "village": farmer.village,
                "district": farmer.district,
                "state": farmer.state,
                "aadhaar_number": farmer.aadhaar_number,
                "occupation": farmer.occupation,
            }

        proposal_list.append(proposal_data)

    # Get claims needing vet review
    claim_result = await db.execute(
        select(Claim).where(
            Claim.status.in_(["submitted", "vet_review"])
        ).order_by(Claim.created_at.desc())
    )
    claims = claim_result.scalars().all()

    claim_list = []
    for c in claims:
        # Get animal for claim
        animal_result = await db.execute(
            select(Animal).where(Animal.id == c.animal_id)
        )
        animal = animal_result.scalar_one_or_none()

        claim_data = {
            "id": str(c.id),
            "policy_id": str(c.policy_id),
            "animal_id": str(c.animal_id),
            "claim_number": c.claim_number,
            "type": c.type,
            "status": c.status,
            "animal_name": c.animal_name,
            "policy_number": c.policy_number,
            "form_data": c.form_data,
            "evidence_media": c.evidence_media or [],
            "ai_muzzle_match_score": c.ai_muzzle_match_score,
            "created_at": to_ist(c.created_at),
            "animal": None,
        }

        if animal:
            claim_data["animal"] = {
                "id": str(animal.id),
                "unique_id": animal.unique_id,
                "species": animal.species,
                "breed": animal.breed,
                "muzzle_images": animal.muzzle_images or [],
                "body_photos": animal.body_photos or [],
                "health_score": animal.health_score,
            }

        claim_list.append(claim_data)

    return {
        "proposals": proposal_list,
        "claims": claim_list,
        "total_pending": len(proposal_list) + len(claim_list),
    }


@router.get("/proposal/{proposal_id}")
async def get_proposal_detail(
    proposal_id: str,
    db: AsyncSession = Depends(get_db),
    vet: User = Depends(get_current_vet),
):
    """Get full proposal details for vet review including animal images and farmer info."""
    result = await db.execute(
        select(Proposal).where(Proposal.id == proposal_id)
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    # Get animal
    animal_result = await db.execute(
        select(Animal).where(Animal.id == proposal.animal_id)
    )
    animal = animal_result.scalar_one_or_none()

    # Get farmer
    farmer_result = await db.execute(
        select(User).where(User.id == proposal.farmer_id)
    )
    farmer = farmer_result.scalar_one_or_none()

    return {
        "id": str(proposal.id),
        "animal_id": str(proposal.animal_id),
        "farmer_id": str(proposal.farmer_id),
        "status": proposal.status,
        "sum_insured": proposal.sum_insured,
        "premium": proposal.premium,
        "animal_name": proposal.animal_name,
        "animal_species": proposal.animal_species,
        "form_data": proposal.form_data,
        "rejection_reason": proposal.rejection_reason,
        "submitted_at": proposal.submitted_at.isoformat() if proposal.submitted_at else None,
        "created_at": proposal.created_at.isoformat() if proposal.created_at else None,
        "animal": {
            "id": str(animal.id),
            "unique_id": animal.unique_id,
            "species": animal.species,
            "breed": animal.breed,
            "sex": animal.sex,
            "sex_condition": animal.sex_condition,
            "color": animal.color,
            "distinguishing_marks": animal.distinguishing_marks,
            "age_years": animal.age_years,
            "height_cm": animal.height_cm,
            "milk_yield_ltr": animal.milk_yield_ltr,
            "market_value": animal.market_value,
            "sum_insured": animal.sum_insured,
            "identification_tag": animal.identification_tag,
            "muzzle_id": animal.muzzle_id,
            "muzzle_images": animal.muzzle_images or [],
            "body_photos": animal.body_photos or [],
            "health_score": animal.health_score,
            "health_risk_category": animal.health_risk_category,
        } if animal else None,
        "farmer": {
            "id": str(farmer.id),
            "name": farmer.name,
            "phone": farmer.phone,
            "email": farmer.email,
            "village": farmer.village,
            "district": farmer.district,
            "state": farmer.state,
            "aadhaar_number": farmer.aadhaar_number,
            "father_or_husband_name": farmer.father_or_husband_name,
            "occupation": farmer.occupation,
        } if farmer else None,
    }
