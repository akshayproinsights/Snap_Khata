"""
User configuration API endpoint.
Returns user-specific configuration for frontend (columns, prompts, dashboard URL, etc.)
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Dict, Any, Optional
import logging

from auth import get_current_user
from config_loader import get_user_config
from database import get_database_client

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/config")
async def get_user_configuration(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get user-specific configuration for frontend.

    Returns configuration including:
    - username
    - industry
    - r2_bucket
    - dashboard_url
    - columns (for all stages: upload, verify_dates, verify_amounts, verified)
    - gemini prompts (optional, for debugging)
    """
    username = current_user.get("username")

    if not username:
        raise HTTPException(status_code=400, detail="No username in token")

    try:
        config = get_user_config(username)

        if not config:
            logger.error(f"Configuration not found for user: {username}")
            raise HTTPException(
                status_code=404,
                detail=f"Configuration not found for user: {username}"
            )

        response = {
            "username": username,
            "industry": config.get("industry"),
            "r2_bucket": config.get("r2_bucket"),
            "dashboard_url": config.get("dashboard_url"),
            "columns": config.get("columns", {}),
            "gemini_config_loaded": "gemini" in config
        }

        logger.info(f"Configuration loaded for user: {username}, industry: {config.get('industry')}")

        return response

    except HTTPException:
        raise

    except Exception as e:
        logger.error(f"Error loading configuration for {username}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load user configuration: {str(e)}"
        )


@router.get("/config/columns")
async def get_user_columns(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get only column configuration for the user.
    Useful for lightweight requests when only column info is needed.
    """
    username = current_user.get("username")

    if not username:
        raise HTTPException(status_code=400, detail="No username in token")

    try:
        config = get_user_config(username)

        if not config:
            raise HTTPException(
                status_code=404,
                detail=f"Configuration not found for user: {username}"
            )

        return {
            "columns": config.get("columns", {})
        }

    except HTTPException:
        raise

    except Exception as e:
        logger.error(f"Error loading columns for {username}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load columns: {str(e)}"
        )


# ─── Shop Profile Endpoints ──────────────────────────────────────────────────

class ShopProfileRequest(BaseModel):
    """Shop profile data from the mobile settings page."""
    shop_name: Optional[str] = None
    shop_address: Optional[str] = None
    shop_phone: Optional[str] = None
    shop_gst: Optional[str] = None


@router.get("/shop-profile")
async def get_shop_profile(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get the shop profile for the authenticated user.
    Returns shop name, address, phone, and GST from user_profiles table.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="No username in token")

    try:
        db = get_database_client()
        resp = (
            db.client.table("user_profiles")
            .select("shop_name, shop_address, shop_phone, shop_gst")
            .eq("username", username)
            .limit(1)
            .execute()
        )
        row = (resp.data or [{}])[0]
        return {
            "shop_name": row.get("shop_name", ""),
            "shop_address": row.get("shop_address", ""),
            "shop_phone": row.get("shop_phone", ""),
            "shop_gst": row.get("shop_gst", ""),
        }
    except Exception as e:
        logger.error(f"Error fetching shop profile for {username}: {e}")
        # Return empty profile gracefully — don't crash the app
        return {"shop_name": "", "shop_address": "", "shop_phone": "", "shop_gst": ""}


@router.post("/shop-profile")
async def save_shop_profile(
    data: ShopProfileRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Save (upsert) shop profile details for the authenticated user.
    Stores into user_profiles table in Supabase — keyed by username.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="No username in token")

    try:
        db = get_database_client()
        upsert_data = {
            "username": username,
            "shop_name": data.shop_name or "",
            "shop_address": data.shop_address or "",
            "shop_phone": data.shop_phone or "",
            "shop_gst": data.shop_gst or "",
        }
        db.client.table("user_profiles") \
            .upsert(upsert_data, on_conflict="username") \
            .execute()

        logger.info(f"Shop profile saved for {username}")
        return {"success": True, "message": "Shop profile saved successfully"}

    except Exception as e:
        logger.error(f"Error saving shop profile for {username}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save shop profile: {str(e)}"
        )
