from fastapi import APIRouter, Depends
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.proposal import Proposal
from ..models.claim import Claim
from ..models.user import User
from ..middleware.auth import get_current_vet

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

    # Get claims needing vet review
    claim_result = await db.execute(
        select(Claim).where(
            Claim.status.in_(["submitted", "vet_review"])
        ).order_by(Claim.created_at.desc())
    )
    claims = claim_result.scalars().all()

    return {
        "proposals": [
            {
                "id": str(p.id),
                "animal_id": str(p.animal_id),
                "farmer_id": str(p.farmer_id),
                "status": p.status,
                "sum_insured": p.sum_insured,
                "animal_name": p.animal_name,
                "animal_species": p.animal_species,
                "submitted_at": p.submitted_at.isoformat() if p.submitted_at else None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in proposals
        ],
        "claims": [
            {
                "id": str(c.id),
                "policy_id": str(c.policy_id),
                "animal_id": str(c.animal_id),
                "claim_number": c.claim_number,
                "type": c.type,
                "status": c.status,
                "animal_name": c.animal_name,
                "policy_number": c.policy_number,
                "created_at": c.created_at.isoformat() if c.created_at else None,
            }
            for c in claims
        ],
        "total_pending": len(proposals) + len(claims),
    }
