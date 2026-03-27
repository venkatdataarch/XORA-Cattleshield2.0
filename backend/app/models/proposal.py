import uuid
from datetime import datetime

from sqlalchemy import String, Float, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class Proposal(Base):
    __tablename__ = "proposals"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    animal_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("animals.id"), index=True
    )
    farmer_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    form_data: Mapped[dict | None] = mapped_column(JSON, default=dict)
    form_schema_version: Mapped[str] = mapped_column(String(20), default="1.0")
    status: Mapped[str] = mapped_column(
        String(50),
        default="draft",
    )
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    uiic_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    sum_insured: Mapped[float] = mapped_column(Float, default=0)
    premium: Mapped[float | None] = mapped_column(Float, nullable=True)
    animal_name: Mapped[str] = mapped_column(String(255), default="")
    animal_species: Mapped[str] = mapped_column(String(50), default="")
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    vet_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    uiic_sent_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    vet_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    vet_remarks: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    animal = relationship("Animal", back_populates="proposals")
    farmer = relationship("User", back_populates="proposals")
    policy = relationship("Policy", back_populates="proposal", uselist=False, lazy="selectin")
