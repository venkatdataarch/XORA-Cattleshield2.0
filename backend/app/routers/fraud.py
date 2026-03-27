"""Fraud detection alerts API."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..middleware.auth import get_current_user
from ..models.fraud_alert import FraudAlert
from ..models.user import User

router = APIRouter(prefix="/fraud-alerts", tags=["Fraud Detection"])


def _require_admin(user: User):
    """Raise 403 if user is not an admin."""
    if user.role != "admin":
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Admin access required")


@router.get("/")
async def list_fraud_alerts(
    alert_type: str | None = None,
    risk_level: str | None = None,
    resolved: bool | None = None,
    limit: int = Query(default=50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List fraud alerts with optional filters."""
    _require_admin(current_user)
    query = select(FraudAlert).order_by(FraudAlert.timestamp.desc())

    if alert_type:
        query = query.where(FraudAlert.alert_type == alert_type)
    if risk_level:
        query = query.where(FraudAlert.risk_level == risk_level)
    if resolved is not None:
        query = query.where(FraudAlert.resolved == resolved)

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    alerts = result.scalars().all()

    return {
        "total": total,
        "alerts": [
            {
                "id": a.id,
                "timestamp": a.timestamp.isoformat() if a.timestamp else None,
                "alert_type": a.alert_type,
                "risk_level": a.risk_level,
                "risk_score": a.risk_score,
                "description": a.description,
                "user_id": a.user_id,
                "animal_id": a.animal_id,
                "policy_id": a.policy_id,
                "claim_id": a.claim_id,
                "contributing_factors": a.contributing_factors,
                "gps_latitude": a.gps_latitude,
                "gps_longitude": a.gps_longitude,
                "resolved": a.resolved,
                "resolved_by": a.resolved_by,
                "resolved_at": a.resolved_at.isoformat() if a.resolved_at else None,
                "resolution_notes": a.resolution_notes,
            }
            for a in alerts
        ],
    }


@router.get("/stats")
async def fraud_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get fraud alert statistics."""
    _require_admin(current_user)
    total = (await db.execute(select(func.count(FraudAlert.id)))).scalar() or 0
    unresolved = (await db.execute(
        select(func.count(FraudAlert.id)).where(FraudAlert.resolved == False)
    )).scalar() or 0

    high_risk = (await db.execute(
        select(func.count(FraudAlert.id)).where(
            FraudAlert.risk_level == "high",
            FraudAlert.resolved == False,
        )
    )).scalar() or 0

    return {
        "total_alerts": total,
        "unresolved": unresolved,
        "high_risk_active": high_risk,
    }


@router.patch("/{alert_id}/resolve")
async def resolve_fraud_alert(
    alert_id: str,
    resolution_notes: str = "",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a fraud alert as resolved."""
    _require_admin(current_user)
    result = await db.execute(select(FraudAlert).where(FraudAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Alert not found")

    alert.resolved = True
    alert.resolved_by = current_user.id
    alert.resolved_at = datetime.now(timezone.utc)
    alert.resolution_notes = resolution_notes
    return {"status": "resolved", "id": alert_id}


async def create_fraud_alert(
    db: AsyncSession,
    alert_type: str,
    risk_level: str,
    description: str,
    risk_score: float | None = None,
    user_id: str | None = None,
    animal_id: str | None = None,
    policy_id: str | None = None,
    claim_id: str | None = None,
    proposal_id: str | None = None,
    contributing_factors: list | None = None,
    gps_lat: str | None = None,
    gps_lng: str | None = None,
):
    """Utility to create a fraud alert from any part of the app."""
    alert = FraudAlert(
        id=str(uuid.uuid4()),
        timestamp=datetime.now(timezone.utc),
        alert_type=alert_type,
        risk_level=risk_level,
        risk_score=risk_score,
        description=description,
        user_id=user_id,
        animal_id=animal_id,
        policy_id=policy_id,
        claim_id=claim_id,
        proposal_id=proposal_id,
        contributing_factors=contributing_factors,
        gps_latitude=gps_lat,
        gps_longitude=gps_lng,
    )
    db.add(alert)
    return alert
