import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.vet_certificate import VetCertificate
from ..models.user import User
from ..schemas.vet_certificate import CertificateCreateRequest, CertificateResponse
from ..middleware.auth import get_current_user, get_current_vet

router = APIRouter(prefix="/vet-certificates", tags=["Vet Certificates"])


def _cert_response(c: VetCertificate) -> CertificateResponse:
    return CertificateResponse(
        id=str(c.id),
        related_id=str(c.related_id),
        type=c.type,
        form_data=c.form_data or {},
        vet_signature_url=c.vet_signature_url,
        vet_id=str(c.vet_id),
        created_at=c.created_at.isoformat() if c.created_at else None,
    )


@router.get("/", response_model=list[CertificateResponse])
async def list_certificates(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = select(VetCertificate)
    if user.role == "vet":
        query = query.where(VetCertificate.vet_id == user.id)
    query = query.order_by(VetCertificate.created_at.desc())
    result = await db.execute(query)
    certs = result.scalars().all()
    return [_cert_response(c) for c in certs]


@router.post("/", response_model=CertificateResponse, status_code=201)
async def create_certificate(
    req: CertificateCreateRequest,
    db: AsyncSession = Depends(get_db),
    vet: User = Depends(get_current_vet),
):
    cert = VetCertificate(
        related_id=req.related_id,
        type=req.type,
        form_data=req.form_data,
        vet_id=vet.id,
    )
    db.add(cert)
    await db.flush()
    return _cert_response(cert)


@router.get("/{cert_id}", response_model=CertificateResponse)
async def get_certificate(
    cert_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(VetCertificate).where(VetCertificate.id == cert_id)
    )
    cert = result.scalar_one_or_none()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")
    return _cert_response(cert)
