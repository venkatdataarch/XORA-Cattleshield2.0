from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.proposal import Proposal
from ..models.claim import Claim
from ..models.policy import Policy
from ..models.user import User
from ..middleware.auth import get_current_user
from ..utils.timezone import to_ist

router = APIRouter(prefix="/admin", tags=["Admin"])


async def _require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


@router.get("/dashboard")
async def admin_dashboard(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(_require_admin),
):
    """Admin dashboard stats."""
    # Vet-approved proposals waiting for UIIC approval
    pending_result = await db.execute(
        select(func.count()).select_from(Proposal).where(
            Proposal.status == "vet_approved"
        )
    )
    pending_approval = pending_result.scalar() or 0

    # Total policies
    policies_result = await db.execute(
        select(func.count()).select_from(Policy)
    )
    total_policies = policies_result.scalar() or 0

    # Total animals
    animals_result = await db.execute(
        select(func.count()).select_from(Animal)
    )
    total_animals = animals_result.scalar() or 0

    # Total claims
    claims_result = await db.execute(
        select(func.count()).select_from(Claim)
    )
    total_claims = claims_result.scalar() or 0

    # Total farmers
    farmers_result = await db.execute(
        select(func.count()).select_from(User).where(User.role == "farmer")
    )
    total_farmers = farmers_result.scalar() or 0

    # Rejected proposals
    rejected_result = await db.execute(
        select(func.count()).select_from(Proposal).where(
            Proposal.status.in_(["vet_rejected", "uiic_rejected"])
        )
    )
    total_rejected = rejected_result.scalar() or 0

    return {
        "pending_approval": pending_approval,
        "total_policies": total_policies,
        "total_animals": total_animals,
        "total_claims": total_claims,
        "total_farmers": total_farmers,
        "total_rejected": total_rejected,
    }


@router.get("/pending")
async def admin_pending(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(_require_admin),
):
    """Get proposals approved by vet, waiting for UIIC admin approval."""
    result = await db.execute(
        select(Proposal).where(
            Proposal.status == "vet_approved"
        ).order_by(Proposal.vet_reviewed_at.desc())
    )
    proposals = result.scalars().all()

    proposal_list = []
    for p in proposals:
        # Get animal
        animal_result = await db.execute(
            select(Animal).where(Animal.id == p.animal_id)
        )
        animal = animal_result.scalar_one_or_none()

        # Get farmer
        farmer_result = await db.execute(
            select(User).where(User.id == p.farmer_id)
        )
        farmer = farmer_result.scalar_one_or_none()

        proposal_list.append({
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
            "vet_reviewed_at": to_ist(p.vet_reviewed_at),
            "animal": {
                "id": str(animal.id),
                "unique_id": animal.unique_id,
                "species": animal.species,
                "breed": animal.breed,
                "sex": animal.sex,
                "color": animal.color,
                "age_years": animal.age_years,
                "market_value": animal.market_value,
                "muzzle_images": animal.muzzle_images or [],
                "body_photos": animal.body_photos or [],
                "health_score": animal.health_score,
                "health_risk_category": animal.health_risk_category,
            } if animal else None,
            "farmer": {
                "id": str(farmer.id),
                "name": farmer.name,
                "phone": farmer.phone,
                "village": farmer.village,
                "district": farmer.district,
                "state": farmer.state,
            } if farmer else None,
        })

    return {
        "proposals": proposal_list,
        "total_pending": len(proposal_list),
    }


@router.get("/all-proposals")
async def all_proposals(
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(_require_admin),
):
    """Get all proposals with optional status filter."""
    query = select(Proposal).order_by(Proposal.created_at.desc())
    if status:
        query = query.where(Proposal.status == status)
    result = await db.execute(query)
    proposals = result.scalars().all()

    items = []
    for p in proposals:
        farmer_result = await db.execute(
            select(User).where(User.id == p.farmer_id)
        )
        farmer = farmer_result.scalar_one_or_none()

        items.append({
            "id": str(p.id),
            "status": p.status,
            "sum_insured": p.sum_insured,
            "premium": p.premium,
            "animal_name": p.animal_name,
            "animal_species": p.animal_species,
            "rejection_reason": p.rejection_reason,
            "uiic_reference": p.uiic_reference,
            "farmer_name": farmer.name if farmer else "Unknown",
            "farmer_phone": farmer.phone if farmer else "",
            "submitted_at": to_ist(p.submitted_at),
            "vet_reviewed_at": to_ist(p.vet_reviewed_at),
            "created_at": to_ist(p.created_at),
        })

    return items


@router.get("/notifications")
async def farmer_notifications(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Get notifications for the current user (rejections, approvals)."""
    # Get proposals where farmer was notified (rejected or policy created)
    result = await db.execute(
        select(Proposal).where(
            Proposal.farmer_id == user.id,
            Proposal.status.in_([
                "vet_rejected", "uiic_rejected", "policy_created", "vet_approved"
            ])
        ).order_by(Proposal.created_at.desc())
    )
    proposals = result.scalars().all()

    notifications = []
    for p in proposals:
        if p.status == "vet_rejected":
            notifications.append({
                "type": "rejection",
                "title": "Proposal Rejected by Vet",
                "message": f"Your proposal for {p.animal_name} was rejected. Reason: {p.rejection_reason or 'Not specified'}",
                "animal_name": p.animal_name,
                "status": p.status,
                "date": to_ist(p.vet_reviewed_at),
            })
        elif p.status == "uiic_rejected":
            notifications.append({
                "type": "rejection",
                "title": "Proposal Rejected by UIIC",
                "message": f"Your proposal for {p.animal_name} was rejected by UIIC. Reason: {p.rejection_reason or 'Not specified'}",
                "animal_name": p.animal_name,
                "status": p.status,
                "date": to_ist(p.uiic_sent_at),
            })
        elif p.status == "vet_approved":
            notifications.append({
                "type": "info",
                "title": "Vet Approved - Pending UIIC Review",
                "message": f"Your proposal for {p.animal_name} was approved by the vet and is now pending UIIC admin review.",
                "animal_name": p.animal_name,
                "status": p.status,
                "date": to_ist(p.vet_reviewed_at),
            })
        elif p.status == "policy_created":
            notifications.append({
                "type": "success",
                "title": "Policy Issued!",
                "message": f"Your policy for {p.animal_name} has been issued. Policy #: {p.uiic_reference}",
                "animal_name": p.animal_name,
                "status": p.status,
                "policy_number": p.uiic_reference,
                "date": to_ist(p.uiic_sent_at),
            })

    return notifications
