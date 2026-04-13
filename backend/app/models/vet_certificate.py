import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class VetCertificate(Base):
    __tablename__ = "vet_certificates"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    related_id: Mapped[str] = mapped_column(String(36), index=True)
    type: Mapped[str] = mapped_column(
        String(50),
    )
    form_data: Mapped[dict | None] = mapped_column(JSON, default=dict)
    vet_signature_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    vet_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    vet = relationship("User")
