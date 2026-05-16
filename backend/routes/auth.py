"""Authentication routes for login and user management"""
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import Dict, Any
from datetime import timedelta
import logging

from google.oauth2 import id_token
from google.auth.transport import requests

import auth
import config

logger = logging.getLogger(__name__)

# Google Web Client ID for token verification
GOOGLE_CLIENT_ID = "643787987175-b7e2dbngkom6uhtmnd1aunk09t4ui10d.apps.googleusercontent.com"

router = APIRouter()


class LoginRequest(BaseModel):
    """Login request model"""
    username: str
    password: str


class LoginResponse(BaseModel):
    """Login response model"""
    access_token: str
    token_type: str
    user: Dict[str, Any]


class GoogleAuthRequest(BaseModel):
    """Google authentication request model"""
    id_token: str


class UserResponse(BaseModel):
    """User information response"""
    username: str
    r2_bucket: str


@router.post("/login", response_model=LoginResponse)
async def login(credentials: LoginRequest):
    """
    Authenticate user and return JWT token.
    Username matching is case-insensitive and normalized (spaces → underscores).
    """
    # Normalize username: spaces to underscores, lowercase
    # This handles both self-registered users (already normalized in DB) and legacy users
    normalized_input = credentials.username.strip().replace(" ", "_").lower()
    
    # Resolve canonical username (case-insensitive lookup against secrets.toml)
    users_db = config.get_users_db()
    canonical_username = normalized_input  # default: use normalized input
    for stored_user in users_db.keys():
        if stored_user.lower() == normalized_input:
            canonical_username = stored_user
            break

    user_config = auth.authenticate_user(canonical_username, credentials.password)
    
    if not user_config:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token using CANONICAL username (correct case from secrets.toml)
    access_token_expires = timedelta(minutes=config.settings.jwt_expire_minutes)
    access_token = auth.create_access_token(
        data={"sub": canonical_username},
        expires_delta=access_token_expires
    )
    
    # Prepare user data (exclude password)
    user_data = {
        "username": canonical_username,
        "r2_bucket": user_config.get("r2_bucket", ""),
    }
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user_data
    }


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    """
    Get current authenticated user information
    """
    return {
        "username": current_user.get("username", ""),
        "r2_bucket": current_user.get("r2_bucket", ""),
    }


@router.post("/logout")
async def logout():
    """
    Logout endpoint (client-side token removal)
    """
    return {"message": "Logged out successfully"}


@router.post("/google", response_model=LoginResponse)
async def google_login(credentials: GoogleAuthRequest):
    """
    Authenticate user via Google ID token.
    If the user doesn't exist, they are automatically registered.
    """
    try:
        # Verify the Google token
        idinfo = id_token.verify_oauth2_token(
            credentials.id_token, 
            requests.Request(), 
            GOOGLE_CLIENT_ID
        )
        
        # Extract email and derive username
        email = idinfo.get("email", "")
        if not email:
            raise ValueError("Token does not contain an email address")
            
        # Create username from email (e.g., test@gmail.com -> test)
        base_username = email.split("@")[0]
        normalized_input = base_username.strip().replace(" ", "_").lower()
        
        # Check if user already exists
        users_db = config.get_users_db()
        canonical_username = normalized_input
        user_exists = False
        r2_bucket = ""
        industry = "general"
        
        # 1. Check in secrets.toml / USERS_CONFIG_JSON
        for stored_user in users_db.keys():
            if stored_user.lower() == normalized_input:
                canonical_username = stored_user
                user_exists = True
                from config_loader import get_user_config
                conf = get_user_config(canonical_username)
                if conf:
                    r2_bucket = conf.get("r2_bucket", "")
                break
                
        # 2. Check in DB if not found in config
        if not user_exists:
            try:
                from database import get_database_client
                db = get_database_client()
                resp = db.client.table("users").select("username, r2_bucket").eq("username", normalized_input).limit(1).execute()
                if resp.data:
                    user_exists = True
                    canonical_username = resp.data[0]["username"]
                    r2_bucket = resp.data[0].get("r2_bucket", "")
            except Exception as e:
                logger.error(f"Error checking DB for Google user: {e}")
                
        # 3. Auto-registration for new users
        if not user_exists:
            logger.info(f"Auto-registering new Google user: {canonical_username}")
            import os
            r2_bucket = os.getenv("CLOUDFLARE_R2_DEFAULT_BUCKET") or os.getenv("R2_DEFAULT_BUCKET", "snapkhata-prod")
            
            import secrets
            random_pw = secrets.token_urlsafe(32)
            password_hash = auth.get_password_hash(random_pw)
            
            try:
                from database import get_database_client
                db = get_database_client()
                db.client.table("users").insert({
                    "username": canonical_username,
                    "password_hash": password_hash,
                    "r2_bucket": r2_bucket,
                    "industry": industry,
                }).execute()
                
                # Update user_profiles with Google name
                name = idinfo.get("name", canonical_username)
                db.client.table("user_profiles").upsert(
                    {"username": canonical_username, "shop_name": name},
                    on_conflict="username",
                ).execute()
                
                # Generate user_configs file
                from config_loader import create_user_config_from_template
                create_user_config_from_template(
                    username=canonical_username,
                    industry=industry,
                    r2_bucket=r2_bucket,
                    display_name=name,
                )
            except Exception as e:
                logger.error(f"Failed to auto-register Google user: {e}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to complete Google registration",
                )
                
        # Issue JWT token
        access_token_expires = timedelta(minutes=config.settings.jwt_expire_minutes)
        access_token = auth.create_access_token(
            data={"sub": canonical_username},
            expires_delta=access_token_expires
        )
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "username": canonical_username,
                "r2_bucket": r2_bucket,
            }
        }
    except ValueError as e:
        logger.error(f"Google token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
