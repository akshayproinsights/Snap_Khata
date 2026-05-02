"""
Authentication module using JWT tokens.
Handles user login, token generation, and authentication middleware.

Auth lookup order:
  1. Supabase `users` table  (self-registered users)
  2. secrets.toml / USERS_CONFIG_JSON  (legacy admin accounts)
  Let's test this 
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
import bcrypt as _bcrypt
import logging

from config import settings, get_users_db, get_user_config

logger = logging.getLogger(__name__)

# HTTP Bearer token scheme
security = HTTPBearer()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    try:
        return _bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8") if isinstance(hashed_password, str) else hashed_password,
        )
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False


def get_password_hash(password: str) -> str:
    """Hash a password"""
    salt = _bcrypt.gensalt()
    return _bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expire_minutes)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    
    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode and validate a JWT token"""
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload
    except JWTError as e:
        logger.warning(f"JWT decode error: {e}")
        return None


def _authenticate_from_db(username: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Check Supabase `users` table for self-registered users.
    Returns a minimal user_data dict on success, None if not found or wrong password.
    """
    try:
        from database import get_database_client
        db = get_database_client()
        resp = (
            db.client.table("users")
            .select("username, password_hash, r2_bucket, industry")
            .eq("username", username)
            .limit(1)
            .execute()
        )
        rows = resp.data or []
        if not rows:
            return None

        row = rows[0]
        password_hash = row.get("password_hash", "")

        if not verify_password(password, password_hash):
            logger.warning(f"Invalid password for DB user: {username}")
            return None

        # Build a user_data dict compatible with the rest of the system
        logger.info(f"User authenticated via DB: {username}")
        return {
            "username": row["username"],
            "r2_bucket": row.get("r2_bucket", ""),
            "industry": row.get("industry", "general"),
            "_auth_source": "db",
        }
    except Exception as e:
        logger.error(f"DB auth lookup failed for {username}: {e}")
        return None


def authenticate_user(username: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Authenticate a user. Checks Supabase DB first, then falls back to secrets.toml.
    Returns user config dict on success, None otherwise.
    """
    # ── 1. Try Supabase DB (self-registered users) ────────────────────────────
    db_result = _authenticate_from_db(username, password)
    if db_result is not None:
        return db_result

    # ── 2. Fall back to secrets.toml / USERS_CONFIG_JSON (legacy users) ───────
    user_config = get_user_config(username)

    if not user_config:
        logger.warning(f"User not found in DB or secrets: {username}")
        return None

    stored_password = user_config.get("password")

    if not stored_password:
        logger.warning(f"No password configured for legacy user: {username}")
        return None

    # Secrets.toml supports both bcrypt hashes and plain text passwords
    if stored_password.startswith("$2b$") or stored_password.startswith("$2a$"):
        if not verify_password(password, stored_password):
            logger.warning(f"Invalid password for legacy user: {username}")
            return None
    else:
        if password != stored_password:
            logger.warning(f"Invalid password for legacy user: {username}")
            return None

    logger.info(f"User authenticated via secrets.toml: {username}")
    user_config["_auth_source"] = "secrets"
    return user_config


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    Dependency to get current authenticated user from JWT token.
    Raises HTTPException if token is invalid or expired.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        try:
            token = credentials.credentials
            payload = decode_access_token(token)
            
            if payload is None:
                logger.warning("Token payload is None")
                raise credentials_exception
            
            username: str = payload.get("sub")
            if username is None:
                logger.warning("Username in payload is None")
                raise credentials_exception
            
            # Keep username case as-is (case-sensitive matching)

            # ── Resolve user_data from either DB or secrets.toml ─────────────
            user_data: Optional[Dict[str, Any]] = None

            # 1. Check Supabase users table (self-registered)
            try:
                from database import get_database_client
                db = get_database_client()
                resp = (
                    db.client.table("users")
                    .select("username, r2_bucket, industry")
                    .eq("username", username)
                    .limit(1)
                    .execute()
                )
                rows = resp.data or []
                if rows:
                    row = rows[0]
                    user_data = {
                        "username": row["username"],
                        "r2_bucket": row.get("r2_bucket", ""),
                        "industry": row.get("industry", "general"),
                        "_auth_source": "db",
                    }
            except Exception as db_err:
                logger.warning(f"DB user lookup failed for token validation ({username}): {db_err}")

            # 2. Fall back to secrets.toml for legacy users
            if user_data is None:
                try:
                    legacy_config = get_user_config(username)
                    if legacy_config:
                        user_data = legacy_config.copy()
                        user_data["username"] = username
                        user_data["_auth_source"] = "secrets"
                except Exception as e:
                    logger.error(f"Error loading legacy user config for {username}: {e}")
                    raise HTTPException(status_code=500, detail=f"Config error: {str(e)}")

            if user_data is None:
                logger.warning(f"User not found in DB or secrets for token: {username}")
                raise credentials_exception

            return user_data
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error processing token or user data: {e}")
            raise credentials_exception
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in get_current_user: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Auth error: {str(e)}")


async def get_current_user_r2_bucket(current_user: Dict[str, Any] = Depends(get_current_user)) -> str:
    """
    Dependency to get the current user's R2 bucket.
    Raises HTTPException if r2_bucket is not configured.
    """
    r2_bucket = current_user.get("r2_bucket")
    
    if not r2_bucket:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No r2_bucket configured for user"
        )
    
    return r2_bucket
