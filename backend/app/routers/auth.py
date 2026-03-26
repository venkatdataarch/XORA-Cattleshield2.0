from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.user import User
from ..schemas.auth import (
    LoginRequest, OtpRequest, OtpVerifyRequest,
    RegisterRequest, UserResponse, TokenResponse,
)
from ..utils.security import hash_password, verify_password, create_access_token
from ..middleware.auth import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _user_response(user: User) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        name=user.name,
        phone=user.phone,
        email=user.email,
        role=user.role,
        address=user.address,
        village=user.village,
        district=user.district,
        state=user.state,
        aadhaar_number=user.aadhaar_number,
        father_or_husband_name=user.father_or_husband_name,
        occupation=user.occupation,
        qualification=user.qualification,
        reg_number=user.reg_number,
        created_at=user.created_at.isoformat() if user.created_at else None,
    )


@router.post("/register", response_model=TokenResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check if phone already exists
    result = await db.execute(select(User).where(User.phone == req.phone))
    existing = result.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    user = User(
        name=req.name,
        phone=req.phone,
        email=req.email,
        role=req.role,
        address=req.address,
        village=req.village,
        district=req.district,
        state=req.state,
        aadhaar_number=req.aadhaar_number,
        father_or_husband_name=req.father_or_husband_name,
        occupation=req.occupation,
        qualification=req.qualification,
        reg_number=req.reg_number,
        password_hash=hash_password(req.password) if req.password else None,
    )
    db.add(user)
    await db.flush()

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return TokenResponse(token=token, user=_user_response(user))


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    # Password-based login — for vet, agent, admin
    agent_id = req.effective_agent_id
    login_id = agent_id or (req.phone if req.password else None)

    if login_id and req.password:
        result = await db.execute(select(User).where(User.phone == login_id))
        user = result.scalar_one_or_none()
        if not user or not user.password_hash:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if not verify_password(req.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        token = create_access_token({"sub": str(user.id), "role": user.role})
        return TokenResponse(token=token, user=_user_response(user))

    # OTP-based login for farmers — send OTP (mock: just return success)
    if req.phone:
        result = await db.execute(select(User).where(User.phone == req.phone))
        user = result.scalar_one_or_none()
        if not user:
            # Auto-create farmer account for OTP flow
            user = User(name="", phone=req.phone, role="farmer")
            db.add(user)
            await db.flush()
        return TokenResponse(
            token="otp-pending",
            user=_user_response(user),
        )

    raise HTTPException(status_code=400, detail="Provide phone or agent_id+password")


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(req: OtpVerifyRequest, db: AsyncSession = Depends(get_db)):
    # Mock OTP verification — any 6-digit code works
    if len(req.otp) != 6 or not req.otp.isdigit():
        raise HTTPException(status_code=400, detail="Invalid OTP. Please enter 6 digits.")

    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()
    if not user:
        user = User(name="", phone=req.phone, role="farmer")
        db.add(user)
        await db.flush()

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return TokenResponse(token=token, user=_user_response(user))


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return _user_response(user)
