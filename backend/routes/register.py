"""
Self-service Registration API.

Allows any shop owner to create an account without manual server intervention.

POST /api/auth/register
  - Checks username uniqueness (DB + secrets.toml)
  - Hashes password with bcrypt
  - Inserts row into Supabase `users` table
  - Generates user_configs/{username}.json from the selected industry template
  - Returns a JWT token (user is logged in immediately)

GET /api/auth/industries
  - Returns list of supported industry templates (id, display, icon)
"""
import re
import logging
from datetime import timedelta
from typing import Dict, Any, Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, field_validator

import config as app_config
import auth
from config_loader import (
    create_user_config_from_template,
    list_available_industries,
    get_user_config as loader_get_user_config,
)

router = APIRouter()
logger = logging.getLogger(__name__)

# ── Validation constants ──────────────────────────────────────────────────────
_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,30}$")
_MIN_PASSWORD_LEN = 6


# ── Request / Response models ─────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    """Registration form submitted by a new shop owner."""
    username: str
    password: str
    shop_name: str
    industry: str = "general"   # must match a template ID

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        v = v.strip()
        # Convert spaces to underscores for better UX (e.g., "Omkar Khanapure" → "omkar_khanapure")
        v = v.replace(" ", "_")
        # Convert to lowercase for consistency
        v = v.lower()
        if not _USERNAME_RE.match(v):
            raise ValueError(
                "Username must be 3–30 characters and contain only letters, "
                "numbers, or underscores (no spaces)."
            )
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < _MIN_PASSWORD_LEN:
            raise ValueError(f"Password must be at least {_MIN_PASSWORD_LEN} characters.")
        return v

    @field_validator("shop_name")
    @classmethod
    def validate_shop_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Shop name cannot be empty.")
        return v


class RegisterResponse(BaseModel):
    """Returned on successful registration (mirrors the login response)."""
    access_token: str
    token_type: str
    user: Dict[str, Any]


# ── Helpers ───────────────────────────────────────────────────────────────────

def _username_exists_in_secrets(username: str) -> bool:
    """Return True if the username is already in secrets.toml / USERS_CONFIG_JSON."""
    try:
        users_db = app_config.get_users_db()
        # Case-insensitive check (same logic as the login endpoint)
        return any(k.lower() == username.lower() for k in users_db)
    except Exception:
        return False


def _username_exists_in_db(username: str) -> bool:
    """Return True if the username already exists in the Supabase users table."""
    try:
        from database import get_database_client
        db = get_database_client()
        resp = (
            db.client.table("users")
            .select("username")
            .eq("username", username)
            .limit(1)
            .execute()
        )
        return bool(resp.data)
    except Exception as e:
        logger.error(f"Error checking DB for username '{username}': {e}")
        # Treat as "exists" to be safe — better to reject than to create a duplicate
        return True


def _derive_r2_bucket(username: str) -> str:
    """
    Return the shared Cloudflare R2 bucket for all new self-registered users.

    All tenants share one bucket.  Files are scoped by '{username}/' prefix,
    so there is no collision.  The bucket MUST be set via the environment
    variable CLOUDFLARE_R2_DEFAULT_BUCKET (pointing to a bucket that already
    exists in your R2 account).
    """
    import os
    # Primary: explicit shared-bucket env var
    bucket = os.getenv("CLOUDFLARE_R2_DEFAULT_BUCKET") or os.getenv("R2_DEFAULT_BUCKET")
    if bucket:
        return bucket.strip()

    # Secondary: fall back to adnak-sir-invoices (production shared bucket)
    logger.warning(
        "CLOUDFLARE_R2_DEFAULT_BUCKET not set — defaulting to 'snapkhata-prod'. "
        "Set this env var to avoid this warning."
    )
    return "snapkhata-prod"


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/industries")
async def get_industries():
    """
    List all supported industry templates that a new user can pick during
    onboarding.

    Returns a list of:
      { "id": "automobile", "display": "Automobile / Garage", "icon": "🚗" }
    """
    return {"industries": list_available_industries()}


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterRequest):
    """
    Register a new shop owner account.

    Steps:
      1. Validate username uniqueness (DB + secrets.toml)
      2. Hash password
      3. Insert into `users` table
      4. Generate user_configs/{username}.json from template
      5. Return JWT (user is logged in immediately)
    """
    username = data.username

    # ── 1. Check uniqueness ──────────────────────────────────────────────
    if _username_exists_in_secrets(username):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already taken. Please choose a different one.",
        )
    if _username_exists_in_db(username):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already taken. Please choose a different one.",
        )

    # ── 2. Hash password ─────────────────────────────────────────────────
    password_hash = auth.get_password_hash(data.password)

    # ── 3. Derive R2 bucket ──────────────────────────────────────────────
    r2_bucket = _derive_r2_bucket(username)

    # ── 4. Insert into DB ────────────────────────────────────────────────
    try:
        from database import get_database_client
        db = get_database_client()
        db.client.table("users").insert({
            "username": username,
            "password_hash": password_hash,
            "r2_bucket": r2_bucket,
            "industry": data.industry,
        }).execute()
        logger.info(f"New user registered in DB: {username} (industry={data.industry})")
    except Exception as e:
        logger.error(f"DB insert failed for new user '{username}': {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create account. Please try again.",
        )

    # ── 5. Generate user config from template ────────────────────────────
    try:
        create_user_config_from_template(
            username=username,
            industry=data.industry,
            r2_bucket=r2_bucket,
            display_name=data.shop_name,
        )
    except Exception as e:
        # Non-fatal: log the error but don't roll back the DB row.
        # The user can still log in; config will be generated on next load.
        logger.error(f"Config generation failed for '{username}': {e}")

    # ── 6. Also upsert into user_profiles (shop_name) ───────────────────
    try:
        from database import get_database_client
        db = get_database_client()
        db.client.table("user_profiles").upsert(
            {"username": username, "shop_name": data.shop_name},
            on_conflict="username",
        ).execute()
    except Exception as e:
        logger.warning(f"Could not save shop_name to user_profiles for '{username}': {e}")

    # ── 7. Issue JWT and return ──────────────────────────────────────────
    access_token = auth.create_access_token(
        data={"sub": username},
        expires_delta=timedelta(minutes=app_config.settings.jwt_expire_minutes),
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "username": username,
            "r2_bucket": r2_bucket,
            "industry": data.industry,
            "shop_name": data.shop_name,
        },
    }
