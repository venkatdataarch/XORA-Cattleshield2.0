from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.animal import Animal
from ..models.claim import Claim
from ..models.policy import Policy
from ..models.proposal import Proposal
from ..models.user import User
from ..middleware.auth import get_current_user

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats")
async def get_dashboard_stats(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Get aggregated dashboard statistics for the logged-in farmer.
    Returns counts for animals, policies, proposals, and claims.
    """
    user_id = user.id
    now = datetime.utcnow()
    thirty_days = now + timedelta(days=30)

    # Total animals
    result = await db.execute(
        select(func.count(Animal.id)).where(Animal.user_id == user_id)
    )
    total_animals = result.scalar() or 0

    # Active policies (not expired)
    result = await db.execute(
        select(func.count(Policy.id)).where(
            Policy.animal_id.in_(
                select(Animal.id).where(Animal.user_id == user_id)
            ),
            Policy.end_date >= now,
        )
    )
    active_policies = result.scalar() or 0

    # Expiring soon (within 30 days)
    result = await db.execute(
        select(func.count(Policy.id)).where(
            Policy.animal_id.in_(
                select(Animal.id).where(Animal.user_id == user_id)
            ),
            Policy.end_date >= now,
            Policy.end_date <= thirty_days,
        )
    )
    expiring_policies = result.scalar() or 0

    # Expired policies
    result = await db.execute(
        select(func.count(Policy.id)).where(
            Policy.animal_id.in_(
                select(Animal.id).where(Animal.user_id == user_id)
            ),
            Policy.end_date < now,
        )
    )
    expired_policies = result.scalar() or 0

    # Pending proposals (submitted, not yet approved/rejected)
    result = await db.execute(
        select(func.count(Proposal.id)).where(
            Proposal.farmer_id == user_id,
            Proposal.status.in_(["draft", "submitted", "vet_review"]),
        )
    )
    pending_proposals = result.scalar() or 0

    # Pending claims
    result = await db.execute(
        select(func.count(Claim.id)).where(
            Claim.animal_id.in_(
                select(Animal.id).where(Animal.user_id == user_id)
            ),
            Claim.status.in_(["submitted", "vet_review"]),
        )
    )
    pending_claims = result.scalar() or 0

    return {
        "total_animals": total_animals,
        "active_policies": active_policies,
        "expiring_policies": expiring_policies,
        "expired_policies": expired_policies,
        "pending_proposals": pending_proposals,
        "pending_claims": pending_claims,
    }
