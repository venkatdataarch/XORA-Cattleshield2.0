import uuid
import random
from datetime import datetime, date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.proposal import Proposal
from ..models.policy import Policy
from ..models.user import User
from ..schemas.proposal import (
    ProposalCreateRequest, ProposalUpdateRequest,
    VetDecisionRequest, ProposalResponse,
    AnimalDetail, FarmerDetail,
)
from ..middleware.auth import get_current_user, get_current_vet

router = APIRouter(prefix="/proposals", tags=["Proposals"])


def _proposal_response(p: Proposal) -> ProposalResponse:
    return ProposalResponse(
        id=str(p.id),
        animal_id=str(p.animal_id),
        farmer_id=str(p.farmer_id),
        form_data=p.form_data or {},
        form_schema_version=p.form_schema_version,
        status=p.status,
        rejection_reason=p.rejection_reason,
        uiic_reference=p.uiic_reference,
        sum_insured=p.sum_insured,
        premium=p.premium,
        animal_name=p.animal_name,
        animal_species=p.animal_species,
        submitted_at=p.submitted_at.isoformat() if p.submitted_at else None,
        vet_reviewed_at=p.vet_reviewed_at.isoformat() if p.vet_reviewed_at else None,
        uiic_sent_at=p.uiic_sent_at.isoformat() if p.uiic_sent_at else None,
        created_at=p.created_at.isoformat() if p.created_at else None,
    )


@router.get("/", response_model=list[ProposalResponse])
async def list_proposals(
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = select(Proposal).where(Proposal.farmer_id == user.id)
    if status:
        query = query.where(Proposal.status == status)
    query = query.order_by(Proposal.created_at.desc())
    result = await db.execute(query)
    proposals = result.scalars().all()
    return [_proposal_response(p) for p in proposals]


@router.post("/", response_model=ProposalResponse, status_code=201)
async def create_proposal(
    req: ProposalCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Get animal details for denormalization
    result = await db.execute(
        select(Animal).where(Animal.id == req.animal_id)
    )
    animal = result.scalar_one_or_none()
    if not animal:
        raise HTTPException(status_code=404, detail="Animal not found")

    premium = round(req.sum_insured * 0.04, 2)  # 4% premium rate

    proposal = Proposal(
        animal_id=animal.id,
        farmer_id=user.id,
        form_data=req.form_data,
        status="draft",
        sum_insured=req.sum_insured or animal.sum_insured,
        premium=premium,
        animal_name=f"{animal.breed} {animal.species}".strip(),
        animal_species=animal.species,
    )
    db.add(proposal)
    await db.flush()
    return _proposal_response(proposal)


@router.get("/{proposal_id}", response_model=ProposalResponse)
async def get_proposal(
    proposal_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Proposal).where(Proposal.id == proposal_id)
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")
    # Ownership check: only the owning farmer or vet/admin can view
    if user.role not in ("vet", "admin") and str(proposal.farmer_id) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to view this proposal")

    resp = _proposal_response(proposal)

    # Fetch animal details
    animal_result = await db.execute(
        select(Animal).where(Animal.id == proposal.animal_id)
    )
    animal = animal_result.scalar_one_or_none()
    if animal:
        resp.animal = AnimalDetail(
            id=str(animal.id),
            unique_id=animal.unique_id or "",
            species=animal.species or "",
            breed=animal.breed or "",
            sex=animal.sex or "",
            sex_condition=animal.sex_condition,
            color=animal.color or "",
            age_years=animal.age_years,
            height_cm=animal.height_cm,
            milk_yield_ltr=animal.milk_yield_ltr,
            market_value=animal.market_value,
            distinguishing_marks=animal.distinguishing_marks,
            identification_tag=animal.identification_tag,
            health_score=animal.health_score,
            health_risk_category=animal.health_risk_category,
            muzzle_images=animal.muzzle_images or [],
            body_photos=animal.body_photos or [],
        )

    # Fetch farmer details
    farmer_result = await db.execute(
        select(User).where(User.id == proposal.farmer_id)
    )
    farmer = farmer_result.scalar_one_or_none()
    if farmer:
        resp.farmer = FarmerDetail(
            id=str(farmer.id),
            name=farmer.name or "",
            phone=farmer.phone or "",
            village=farmer.village,
            district=farmer.district,
            state=farmer.state,
            aadhaar_number=farmer.aadhaar_number,
            father_or_husband_name=farmer.father_or_husband_name,
            occupation=farmer.occupation,
        )

    return resp


@router.put("/{proposal_id}", response_model=ProposalResponse)
async def update_proposal(
    proposal_id: str,
    req: ProposalUpdateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Proposal).where(
            Proposal.id == proposal_id,
            Proposal.farmer_id == user.id,
        )
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    if req.form_data is not None:
        proposal.form_data = req.form_data

    await db.flush()
    return _proposal_response(proposal)


@router.patch("/{proposal_id}", response_model=ProposalResponse)
async def submit_proposal(
    proposal_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Proposal).where(
            Proposal.id == proposal_id,
            Proposal.farmer_id == user.id,
        )
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    if proposal.status != "draft":
        raise HTTPException(status_code=400, detail="Can only submit draft proposals")

    proposal.status = "submitted"
    proposal.submitted_at = datetime.utcnow()
    await db.flush()
    return _proposal_response(proposal)


@router.post("/{proposal_id}/vet-decision", response_model=ProposalResponse)
async def vet_decision(
    proposal_id: str,
    req: VetDecisionRequest,
    db: AsyncSession = Depends(get_db),
    vet: User = Depends(get_current_vet),
):
    result = await db.execute(
        select(Proposal).where(Proposal.id == proposal_id)
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    if proposal.status != "submitted":
        raise HTTPException(status_code=400, detail="Proposal is not in submitted status")

    proposal.vet_reviewed_at = datetime.utcnow()
    proposal.vet_id = str(vet.id)
    proposal.vet_remarks = req.reason

    if req.decision == "approved":
        # Vet approved → goes to UIIC Admin for final approval
        proposal.status = "vet_approved"
    else:
        proposal.status = "vet_rejected"
        proposal.rejection_reason = req.reason

    await db.flush()
    return _proposal_response(proposal)


@router.post("/{proposal_id}/admin-decision", response_model=ProposalResponse)
async def admin_decision(
    proposal_id: str,
    req: VetDecisionRequest,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_user),
):
    """UIIC Admin approves or rejects a vet-approved proposal."""
    if admin.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    result = await db.execute(
        select(Proposal).where(Proposal.id == proposal_id)
    )
    proposal = result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    if proposal.status != "vet_approved":
        raise HTTPException(status_code=400, detail="Proposal must be vet-approved first")

    proposal.uiic_sent_at = datetime.utcnow()

    if req.decision == "approved":
        proposal.status = "uiic_approved"

        # Now create the policy
        animal_result = await db.execute(
            select(Animal).where(Animal.id == proposal.animal_id)
        )
        animal = animal_result.scalar_one_or_none()

        farmer_result = await db.execute(
            select(User).where(User.id == proposal.farmer_id)
        )
        farmer = farmer_result.scalar_one_or_none()

        policy_number = f"UIIC-CS-{random.randint(100000, 999999)}"
        today = date.today()

        policy = Policy(
            proposal_id=proposal.id,
            animal_id=proposal.animal_id,
            policy_number=policy_number,
            insured_name=farmer.name if farmer else "",
            sum_insured=proposal.sum_insured,
            premium=proposal.premium or 0,
            start_date=today,
            end_date=today + timedelta(days=365),
            animal_name=proposal.animal_name,
            animal_species=proposal.animal_species,
            details_json={
                "coverage_type": "comprehensive",
                "deductible": 0,
                "vet_approved_by": str(proposal.form_data.get("vet_id", "")),
                "uiic_approved_by": str(admin.id),
            },
        )
        db.add(policy)

        proposal.status = "policy_created"
        proposal.uiic_reference = policy_number
    else:
        proposal.status = "uiic_rejected"
        proposal.rejection_reason = req.reason

    await db.flush()
    return _proposal_response(proposal)
