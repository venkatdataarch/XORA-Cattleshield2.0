import uuid
from datetime import datetime, date

from sqlalchemy import String, Float, Date, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class Policy(Base):
    __tablename__ = "policies"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    proposal_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("proposals.id"), index=True
    )
    animal_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("animals.id"), index=True
    )
    policy_number: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    insured_name: Mapped[str] = mapped_column(String(255), default="")
    sum_insured: Mapped[float] = mapped_column(Float, default=0)
    premium: Mapped[float] = mapped_column(Float, default=0)
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    animal_name: Mapped[str] = mapped_column(String(255), default="")
    animal_species: Mapped[str] = mapped_column(String(50), default="")
    details_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    proposal = relationship("Proposal", back_populates="policy")
    animal = relationship("Animal", back_populates="policies")
    claims = relationship("Claim", back_populates="policy", lazy="selectin")
