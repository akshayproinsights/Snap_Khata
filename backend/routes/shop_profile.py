"""Shop profile endpoints — GET and POST /api/shop-profile"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, Dict, Any
import logging

import auth

logger = logging.getLogger(__name__)

router = APIRouter()


class ShopProfileResponse(BaseModel):
    shop_name: Optional[str] = ""
    shop_address: Optional[str] = ""
    shop_phone: Optional[str] = ""
    shop_gst: Optional[str] = ""
    shop_upi_id: Optional[str] = ""


class ShopProfileRequest(BaseModel):
    shop_name: Optional[str] = ""
    shop_address: Optional[str] = ""
    shop_phone: Optional[str] = ""
    shop_gst: Optional[str] = ""
    shop_upi_id: Optional[str] = ""


@router.get("/shop-profile", response_model=ShopProfileResponse)
async def get_shop_profile(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    """
    Return the authenticated user's shop profile from user_profiles.
    Returns empty strings for any fields not yet set.
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        from database import get_database_client
        db = get_database_client()
        resp = (
            db.client.table("user_profiles")
            .select("shop_name, shop_address, shop_phone, shop_gst, shop_upi_id")
            .eq("username", username)
            .limit(1)
            .execute()
        )
        if resp.data:
            row = resp.data[0]
            return ShopProfileResponse(
                shop_name=row.get("shop_name") or "",
                shop_address=row.get("shop_address") or "",
                shop_phone=row.get("shop_phone") or "",
                shop_gst=row.get("shop_gst") or "",
                shop_upi_id=row.get("shop_upi_id") or "",
            )
        # No row yet — return empty defaults
        return ShopProfileResponse()
    except Exception as e:
        logger.error(f"Error fetching shop profile for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch shop profile")


@router.post("/shop-profile", response_model=ShopProfileResponse)
async def update_shop_profile(
    body: ShopProfileRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
):
    """
    Upsert the authenticated user's shop profile in user_profiles.
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        from database import get_database_client
        db = get_database_client()
        db.client.table("user_profiles").upsert(
            {
                "username": username,
                "shop_name": body.shop_name or "",
                "shop_address": body.shop_address or "",
                "shop_phone": body.shop_phone or "",
                "shop_gst": body.shop_gst or "",
                "shop_upi_id": body.shop_upi_id or "",
            },
            on_conflict="username",
        ).execute()

        logger.info(f"Shop profile updated for {username}: '{body.shop_name}'")
        return ShopProfileResponse(
            shop_name=body.shop_name or "",
            shop_address=body.shop_address or "",
            shop_phone=body.shop_phone or "",
            shop_gst=body.shop_gst or "",
            shop_upi_id=body.shop_upi_id or "",
        )
    except Exception as e:
        logger.error(f"Error updating shop profile for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to save shop profile")
