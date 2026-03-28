import hashlib
import secrets
from datetime import datetime, timedelta
from jose import jwt, JWTError

from ..config import get_settings

settings = get_settings()


def hash_password(password: str) -> str:
    """Hash password using SHA-256 with salt (Python 3.14 compatible)."""
    salt = secrets.token_hex(16)
    hashed = hashlib.sha256(f"{salt}{password}".encode()).hexdigest()
    return f"{salt}${hashed}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    if "$" not in hashed_password:
        return False
    salt, stored_hash = hashed_password.split("$", 1)
    check_hash = hashlib.sha256(f"{salt}{plain_password}".encode()).hexdigest()
    return check_hash == stored_hash


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=settings.jwt_expire_minutes)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        return payload
    except JWTError:
        return None
