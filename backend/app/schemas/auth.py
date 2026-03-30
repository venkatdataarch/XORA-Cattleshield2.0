from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class LoginRequest(BaseModel):
    agent_id: str | None = None
    agentId: str | None = None  # Flutter sends camelCase
    password: str | None = None
    phone: str | None = None

    @property
    def effective_agent_id(self) -> str | None:
        return self.agent_id or self.agentId


class OtpRequest(BaseModel):
    phone: str


class OtpVerifyRequest(BaseModel):
    phone: str
    otp: str


class RegisterRequest(BaseModel):
    name: str
    phone: str
    email: str | None = None
    role: str = "farmer"
    address: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None
    aadhaar_number: str | None = None
    father_or_husband_name: str | None = None
    occupation: str | None = None
    qualification: str | None = None
    reg_number: str | None = None
    password: str | None = None


class UserResponse(BaseModel):
    id: str
    name: str
    phone: str
    email: str | None = None
    role: str
    address: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None
    aadhaar_number: str | None = None
    father_or_husband_name: str | None = None
    occupation: str | None = None
    qualification: str | None = None
    reg_number: str | None = None
    created_at: str | None = None

    class Config:
        from_attributes = True


class ProfileUpdateRequest(BaseModel):
    name: str | None = None
    email: str | None = None
    address: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None


class TokenResponse(BaseModel):
    token: str
    user: UserResponse
