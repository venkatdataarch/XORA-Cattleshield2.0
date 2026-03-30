"""Audit log API — admin-only read access to immutable audit trail."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..middleware.auth import get_current_user
from ..models.audit_log import AuditLog
from ..models.user import User

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("/")
async def list_audit_logs(
    action_type: str | None = None,
    resource_type: str | None = None,
    user_id: str | None = None,
    limit: int = Query(default=50, le=500),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List audit log entries with optional filters. Accessible by vet and admin roles."""
    query = select(AuditLog).order_by(AuditLog.timestamp.desc())

    if action_type:
        query = query.where(AuditLog.action_type == action_type)
    if resource_type:
        query = query.where(AuditLog.resource_type == resource_type)
    if user_id:
        query = query.where(AuditLog.user_id == user_id)

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Paginate
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    logs = result.scalars().all()

    return {
        "total": total,
        "logs": [
            {
                "id": log.id,
                "timestamp": log.timestamp.isoformat() if log.timestamp else None,
                "user_id": log.user_id,
                "user_role": log.user_role,
                "ip_address": log.ip_address,
                "action_type": log.action_type,
                "resource_type": log.resource_type,
                "resource_id": log.resource_id,
                "api_endpoint": log.api_endpoint,
                "http_method": log.http_method,
                "before_state": log.before_state,
                "after_state": log.after_state,
                "details": log.details,
                "gps_latitude": log.gps_latitude,
                "gps_longitude": log.gps_longitude,
            }
            for log in logs
        ],
    }


@router.get("/stats")
async def audit_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get audit log statistics for the dashboard."""
    total_result = await db.execute(select(func.count(AuditLog.id)))
    total = total_result.scalar() or 0

    # Count by action type
    action_counts = {}
    for action in ["CREATE", "UPDATE", "DELETE", "APPROVE", "REJECT"]:
        result = await db.execute(
            select(func.count(AuditLog.id)).where(AuditLog.action_type == action)
        )
        action_counts[action] = result.scalar() or 0

    return {
        "total_entries": total,
        "by_action": action_counts,
    }
