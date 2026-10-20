"""
Authentication & Security Module
Provides session / token validation, header checks, and audit logging.
"""

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader
from ..config import settings

API_KEY_HEADER = APIKeyHeader(name="X-API-KEY", auto_error=False)

def verify_api_key(api_key: str = Security(API_KEY_HEADER)):
    """Verifies private API key header if enabled."""
    if not settings.DEBUG and api_key != settings.SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-KEY header."
        )
    return True
