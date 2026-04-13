import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Text, JSON
from ..database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    user_id = Column(String, nullable=True)
    user_role = Column(String, nullable=True)
    ip_address = Column(String, nullable=True)
    action_type = Column(String, nullable=False)  # CREATE, READ, UPDATE, DELETE, APPROVE, REJECT
    resource_type = Column(String, nullable=False)  # e.g. "animal", "proposal", "claim"
    resource_id = Column(String, nullable=True)
    api_endpoint = Column(String, nullable=True)
    http_method = Column(String, nullable=True)
    before_state = Column(JSON, nullable=True)
    after_state = Column(JSON, nullable=True)
    details = Column(Text, nullable=True)  # Human-readable description
    gps_latitude = Column(String, nullable=True)
    gps_longitude = Column(String, nullable=True)
