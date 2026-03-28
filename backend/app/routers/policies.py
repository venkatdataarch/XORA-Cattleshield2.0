import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.policy import Policy
from ..models.proposal import Proposal
from ..models.user import User
from ..schemas.policy import PolicyResponse
from ..middleware.auth import get_current_user

router = APIRouter(prefix="/policies", tags=["Policies"])


def _policy_response(p: Policy) -> PolicyResponse:
    return PolicyResponse(
        id=str(p.id),
        proposal_id=str(p.proposal_id),
        animal_id=str(p.animal_id),
        policy_number=p.policy_number,
        insured_name=p.insured_name,
        sum_insured=p.sum_insured,
        premium=p.premium,
        start_date=p.start_date.isoformat() if p.start_date else "",
        end_date=p.end_date.isoformat() if p.end_date else "",
        animal_name=p.animal_name,
        animal_species=p.animal_species,
        details_json=p.details_json,
        created_at=p.created_at.isoformat() if p.created_at else None,
    )


@router.get("/", response_model=list[PolicyResponse])
async def list_policies(
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Get policies for animals owned by this user
    query = (
        select(Policy)
        .join(Proposal, Policy.proposal_id == Proposal.id)
        .where(Proposal.farmer_id == user.id)
        .order_by(Policy.created_at.desc())
    )
    result = await db.execute(query)
    policies = result.scalars().all()
    return [_policy_response(p) for p in policies]


@router.get("/{policy_id}", response_model=PolicyResponse)
async def get_policy(
    policy_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Policy).where(Policy.id == policy_id)
    )
    policy = result.scalar_one_or_none()
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")
    # Ownership check: verify via animal owner or allow vet/admin
    if user.role not in ("vet", "admin"):
        animal_result = await db.execute(
            select(Animal).where(Animal.id == policy.animal_id)
        )
        animal = animal_result.scalar_one_or_none()
        if not animal or str(animal.user_id) != str(user.id):
            raise HTTPException(status_code=403, detail="Not authorized to view this policy")
    return _policy_response(policy)
