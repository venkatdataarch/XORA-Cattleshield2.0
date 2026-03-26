import uuid
import random
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.claim import Claim
from ..models.policy import Policy
from ..models.animal import Animal
from ..models.user import User
from ..schemas.claim import ClaimCreateRequest, VetClaimDecisionRequest, ClaimResponse
from ..middleware.auth import get_current_user, get_current_vet
from ..utils.file_storage import save_upload
from .fraud import create_fraud_alert

router = APIRouter(prefix="/claims", tags=["Claims"])


def _claim_response(c: Claim) -> ClaimResponse:
    return ClaimResponse(
        id=str(c.id),
        policy_id=str(c.policy_id),
        animal_id=str(c.animal_id),
        claim_number=c.claim_number,
        type=c.type,
        form_data=c.form_data or {},
        evidence_media=c.evidence_media or [],
        ai_muzzle_match_score=c.ai_muzzle_match_score,
        ai_match_result=c.ai_match_result,
        status=c.status,
        settlement_amount=c.settlement_amount,
        settled_at=c.settled_at.isoformat() if c.settled_at else None,
        rejection_reason=c.rejection_reason,
        animal_name=c.animal_name,
        policy_number=c.policy_number,
        created_at=c.created_at.isoformat() if c.created_at else None,
    )


@router.get("/", response_model=list[ClaimResponse])
async def list_claims(
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    from ..models.proposal import Proposal
    query = (
        select(Claim)
        .join(Policy, Claim.policy_id == Policy.id)
        .join(Proposal, Policy.proposal_id == Proposal.id)
        .where(Proposal.farmer_id == user.id)
    )
    if status:
        query = query.where(Claim.status == status)
    query = query.order_by(Claim.created_at.desc())
    result = await db.execute(query)
    claims = result.scalars().all()
    return [_claim_response(c) for c in claims]


@router.post("/", response_model=ClaimResponse, status_code=201)
async def create_claim(
    req: ClaimCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Get policy
    policy_result = await db.execute(
        select(Policy).where(Policy.id == req.policy_id)
    )
    policy = policy_result.scalar_one_or_none()
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")

    claim_number = f"CLM-{uuid.uuid4().hex[:8].upper()}"

    claim = Claim(
        policy_id=policy.id,
        animal_id=policy.animal_id,
        claim_number=claim_number,
        type=req.type,
        form_data=req.form_data,
        status="submitted",
        animal_name=policy.animal_name,
        policy_number=policy.policy_number,
        evidence_media=[],
    )
    db.add(claim)
    await db.flush()

    # --- Fraud detection checks (Scope 5d) ---
    fraud_factors = []

    # 1. Early claim: within 30 days of policy inception
    if policy.start_date:
        days_since = (datetime.now(timezone.utc).date() - policy.start_date).days
        if days_since < 30:
            fraud_factors.append(f"Early claim: {days_since} days after policy inception")
            await create_fraud_alert(
                db=db, alert_type="early_claim", risk_level="medium",
                description=f"Claim {claim_number} filed only {days_since} days after policy inception",
                user_id=str(user.id), policy_id=str(policy.id), claim_id=str(claim.id),
                contributing_factors=fraud_factors,
            )

    # 2. Claim velocity: same farmer >2 claims in 12 months
    twelve_months_ago = datetime.now(timezone.utc) - timedelta(days=365)
    from ..models.proposal import Proposal
    farmer_claims_q = (
        select(func.count(Claim.id))
        .join(Policy, Claim.policy_id == Policy.id)
        .join(Proposal, Policy.proposal_id == Proposal.id)
        .where(Proposal.farmer_id == user.id, Claim.created_at >= twelve_months_ago)
    )
    farmer_claim_count = (await db.execute(farmer_claims_q)).scalar() or 0
    if farmer_claim_count > 2:
        fraud_factors.append(f"Claim velocity: {farmer_claim_count} claims in 12 months")
        await create_fraud_alert(
            db=db, alert_type="claim_velocity", risk_level="high",
            description=f"Farmer has {farmer_claim_count} claims in last 12 months",
            user_id=str(user.id), claim_id=str(claim.id),
            contributing_factors=fraud_factors,
        )

    return _claim_response(claim)


@router.get("/{claim_id}", response_model=ClaimResponse)
async def get_claim(
    claim_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Claim).where(Claim.id == claim_id)
    )
    claim = result.scalar_one_or_none()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    return _claim_response(claim)


@router.post("/{claim_id}/evidence")
async def upload_evidence(
    claim_id: str,
    files: list[UploadFile] = File(default=[]),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Claim).where(Claim.id == claim_id)
    )
    claim = result.scalar_one_or_none()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")

    evidence = list(claim.evidence_media or [])
    for f in files:
        url = await save_upload(f, subfolder="evidence")
        evidence.append({
            "type": "photo" if f.content_type and "image" in f.content_type else "document",
            "url": url,
            "capturedAt": datetime.utcnow().isoformat(),
            "aiProcessed": False,
        })

    claim.evidence_media = evidence
    await db.flush()
    return {"message": "Evidence uploaded", "count": len(files)}


@router.post("/{claim_id}/muzzle-verify")
async def muzzle_verify(
    claim_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Claim).where(Claim.id == claim_id)
    )
    claim = result.scalar_one_or_none()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")

    # Mock AI muzzle match — wider range to sometimes trigger fraud alerts
    score = round(random.uniform(45.0, 99.0), 1)
    if score >= 80:
        match_result = "verified"
    elif score >= 60:
        match_result = "review_required"
    else:
        match_result = "suspicious"

    claim.ai_muzzle_match_score = score
    claim.ai_match_result = match_result
    await db.flush()

    # Fraud alert if muzzle match is low
    if score < 60:
        await create_fraud_alert(
            db=db, alert_type="muzzle_mismatch", risk_level="high",
            description=f"Muzzle match score {score}% — below 60% threshold for claim {claim.claim_number}",
            risk_score=100 - score,
            claim_id=str(claim.id), animal_id=str(claim.animal_id),
            contributing_factors=[f"Similarity score: {score}%", "Below 60% threshold"],
        )
    elif score < 80:
        await create_fraud_alert(
            db=db, alert_type="muzzle_mismatch", risk_level="medium",
            description=f"Muzzle match score {score}% — flagged for vet review on claim {claim.claim_number}",
            risk_score=100 - score,
            claim_id=str(claim.id), animal_id=str(claim.animal_id),
            contributing_factors=[f"Similarity score: {score}%", "Between 60-80% — requires vet review"],
        )

    return {
        "match_score": score,
        "result": match_result,
        "message": f"Muzzle match: {score}% confidence",
        "enrollment_muzzle_images": [],  # Would contain enrollment photos for side-by-side
        "claim_muzzle_images": [],
    }


@router.post("/{claim_id}/vet-decision", response_model=ClaimResponse)
async def vet_claim_decision(
    claim_id: str,
    req: VetClaimDecisionRequest,
    db: AsyncSession = Depends(get_db),
    vet: User = Depends(get_current_vet),
):
    result = await db.execute(
        select(Claim).where(Claim.id == claim_id)
    )
    claim = result.scalar_one_or_none()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")

    if req.decision == "approved":
        claim.status = "settled"
        claim.settlement_amount = req.settlement_amount or claim.form_data.get("claim_amount", 0)
        claim.settled_at = datetime.utcnow()
    else:
        claim.status = "vet_rejected"
        claim.rejection_reason = req.reason

    await db.flush()
    return _claim_response(claim)
