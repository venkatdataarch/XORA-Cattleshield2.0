import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Float, JSON, Boolean
from ..database import Base


class FraudAlert(Base):
    __tablename__ = "fraud_alerts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    alert_type = Column(String, nullable=False)  # duplicate_muzzle, gps_anomaly, claim_velocity, early_claim, muzzle_mismatch, agent_anomaly
    risk_level = Column(String, nullable=False, default="medium")  # low, medium, high
    risk_score = Column(Float, nullable=True)
    description = Column(String, nullable=False)
    # References
    user_id = Column(String, nullable=True)
    animal_id = Column(String, nullable=True)
    policy_id = Column(String, nullable=True)
    claim_id = Column(String, nullable=True)
    proposal_id = Column(String, nullable=True)
    # Context
    contributing_factors = Column(JSON, nullable=True)  # list of factor descriptions
    gps_latitude = Column(String, nullable=True)
    gps_longitude = Column(String, nullable=True)
    # Resolution
    resolved = Column(Boolean, default=False)
    resolved_by = Column(String, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    resolution_notes = Column(String, nullable=True)
