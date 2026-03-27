"""Audit trail middleware — logs every mutating API call."""

import uuid
from datetime import datetime, timezone, timedelta

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from ..database import async_session
from ..models.audit_log import AuditLog
from ..utils.security import decode_access_token


# Map HTTP methods to action types
_METHOD_ACTION = {
    "POST": "CREATE",
    "PUT": "UPDATE",
    "PATCH": "UPDATE",
    "DELETE": "DELETE",
}


def _extract_resource(path: str) -> tuple[str, str | None]:
    """Extract resource type and ID from API path like /api/animals/abc-123."""
    parts = [p for p in path.split("/") if p and p != "api"]
    resource_type = parts[0] if parts else "unknown"
    resource_id = parts[1] if len(parts) > 1 else None
    return resource_type, resource_id


class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)

        # Only log mutating operations that succeeded
        if request.method not in _METHOD_ACTION:
            return response
        if response.status_code >= 400:
            return response
        if not request.url.path.startswith("/api/"):
            return response

        action_type = _METHOD_ACTION[request.method]
        resource_type, resource_id = _extract_resource(request.url.path)

        # Extract user info from JWT token in Authorization header
        user_id = None
        user_role = None
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ", 1)[1]
            try:
                payload = decode_access_token(token)
                if payload:
                    user_id = payload.get("sub")
                    user_role = payload.get("role")
            except Exception:
                pass

        # Get client IP
        ip_address = request.client.host if request.client else None

        # Get GPS from headers (sent by Flutter app)
        gps_lat = request.headers.get("X-GPS-Latitude")
        gps_lng = request.headers.get("X-GPS-Longitude")

        # Special action types for approval/rejection
        if "vet-decision" in request.url.path or "approve" in request.url.path:
            action_type = "APPROVE"
        if "reject" in request.url.path:
            action_type = "REJECT"

        try:
            async with async_session() as session:
                log_entry = AuditLog(
                    id=str(uuid.uuid4()),
                    timestamp=datetime.now(timezone(timedelta(hours=5, minutes=30))),  # IST
                    user_id=user_id,
                    user_role=user_role,
                    ip_address=ip_address,
                    action_type=action_type,
                    resource_type=resource_type,
                    resource_id=resource_id,
                    api_endpoint=request.url.path,
                    http_method=request.method,
                    gps_latitude=gps_lat,
                    gps_longitude=gps_lng,
                    details=f"{action_type} {resource_type}" + (f" {resource_id}" if resource_id else ""),
                )
                session.add(log_entry)
                await session.commit()
        except Exception:
            pass  # Never let audit logging break the API

        return response
