import uuid
from datetime import datetime

from sqlalchemy import String, Float, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class Claim(Base):
    __tablename__ = "claims"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    policy_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("policies.id"), index=True
    )
    animal_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("animals.id"), index=True
    )
    claim_number: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    type: Mapped[str] = mapped_column(
        String(50),
    )
    form_data: Mapped[dict | None] = mapped_column(JSON, default=dict)
    evidence_media: Mapped[dict | None] = mapped_column(JSON, default=list)
    ai_muzzle_match_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_match_result: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="submitted",
    )
    settlement_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    settled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    animal_name: Mapped[str] = mapped_column(String(255), default="")
    policy_number: Mapped[str] = mapped_column(String(50), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    policy = relationship("Policy", back_populates="claims")
    animal = relationship("Animal", back_populates="claims")
