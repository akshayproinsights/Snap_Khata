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
            "gemini_config_loaded": "gemini" in config,
            "dashboard_visuals": config.get("dashboard_visuals", {}),
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


@router.post("/config/clear-cache")
async def clear_user_config_cache(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Clear the in-memory config cache for the authenticated user.
    Call this whenever the user's industry or config is changed so the
    next request picks up the fresh config from disk/DB instead of
    serving a stale cached version.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="No username in token")

    try:
        from config_loader import _config_cache, _template_cache
        _config_cache.pop(username, None)
        logger.info(f"Config cache cleared for user: {username}")
        return {"success": True, "message": f"Config cache cleared for '{username}'"}
    except Exception as e:
        logger.error(f"Error clearing config cache for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to clear config cache")


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


# NOTE: /shop-profile GET and POST endpoints are defined exclusively in
# shop_profile.py (registered separately in main.py). They were removed
# from this file to eliminate duplicate route registration.
