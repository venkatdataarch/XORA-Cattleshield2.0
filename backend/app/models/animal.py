import uuid
from datetime import datetime

from sqlalchemy import String, Float, Integer, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class Animal(Base):
    __tablename__ = "animals"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    unique_id: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    species: Mapped[str] = mapped_column(
        String(50),
    )
    identification_tag: Mapped[str | None] = mapped_column(String(100), nullable=True)
    breed: Mapped[str] = mapped_column(String(100), default="")
    sex: Mapped[str] = mapped_column(
        String(50),
    )
    sex_condition: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    color: Mapped[str] = mapped_column(String(100), default="")
    distinguishing_marks: Mapped[str | None] = mapped_column(Text, nullable=True)
    age_years: Mapped[float] = mapped_column(Float, default=0)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    milk_yield_ltr: Mapped[float | None] = mapped_column(Float, nullable=True)
    muzzle_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    muzzle_embedding: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON-serialized 2048-dim vector
    muzzle_images: Mapped[dict | None] = mapped_column(JSON, default=list)
    health_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    health_risk_category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    body_photos: Mapped[dict | None] = mapped_column(JSON, default=list)
    market_value: Mapped[float] = mapped_column(Float, default=0)
    sum_insured: Mapped[float] = mapped_column(Float, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    owner = relationship("User", back_populates="animals")
    proposals = relationship("Proposal", back_populates="animal", lazy="selectin")
    policies = relationship("Policy", back_populates="animal", lazy="selectin")
    claims = relationship("Claim", back_populates="animal", lazy="selectin")
