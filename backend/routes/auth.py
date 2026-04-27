"""Authentication routes for login and user management"""
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import Dict, Any
from datetime import timedelta

import auth
import config

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
