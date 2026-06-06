"""Shop profile endpoints — GET and POST /api/shop-profile"""
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from pydantic import BaseModel
from typing import Optional, Dict, Any
import logging
import uuid
import os

import auth

logger = logging.getLogger(__name__)

router = APIRouter()


class ShopProfileResponse(BaseModel):
    shop_name: Optional[str] = ""
    shop_address: Optional[str] = ""
    shop_phone: Optional[str] = ""
    shop_gst: Optional[str] = ""
    shop_upi_id: Optional[str] = ""
    shop_logo_url: Optional[str] = ""
    custom_terms: Optional[str] = ""
    whatsapp_custom_note: Optional[str] = ""
    shop_type: Optional[str] = "general"


class ShopProfileRequest(BaseModel):
    shop_name: Optional[str] = ""
    shop_address: Optional[str] = ""
    shop_phone: Optional[str] = ""
    shop_gst: Optional[str] = ""
    shop_upi_id: Optional[str] = ""
    shop_logo_url: Optional[str] = ""
    custom_terms: Optional[str] = ""
    whatsapp_custom_note: Optional[str] = ""
    shop_type: Optional[str] = "general"


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
            .select("shop_name, shop_address, shop_phone, shop_gst, shop_upi_id, shop_logo_url, custom_terms, whatsapp_custom_note, shop_type")
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
                shop_logo_url=row.get("shop_logo_url") or "",
                custom_terms=row.get("custom_terms") or "",
                whatsapp_custom_note=row.get("whatsapp_custom_note") or "",
                shop_type=row.get("shop_type") or "general",
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
                "shop_logo_url": body.shop_logo_url or "",
                "custom_terms": body.custom_terms or "",
                "whatsapp_custom_note": body.whatsapp_custom_note or "",
                "shop_type": body.shop_type or "general",
            },
            on_conflict="username",
        ).execute()

        logger.info(f"Shop profile updated for {username}: '{body.shop_name}' (type: {body.shop_type})")
        return ShopProfileResponse(
            shop_name=body.shop_name or "",
            shop_address=body.shop_address or "",
            shop_phone=body.shop_phone or "",
            shop_gst=body.shop_gst or "",
            shop_upi_id=body.shop_upi_id or "",
            shop_logo_url=body.shop_logo_url or "",
            custom_terms=body.custom_terms or "",
            whatsapp_custom_note=body.whatsapp_custom_note or "",
            shop_type=body.shop_type or "general",
        )
    except Exception as e:
        logger.error(f"Error updating shop profile for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to save shop profile")


@router.post("/shop-profile/upload-logo")
async def upload_shop_logo(
    file: UploadFile = File(...),
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
    r2_bucket: str = Depends(auth.get_current_user_r2_bucket),
):
    """
    Upload a shop logo image to R2 and return its public URL.
    Accepts JPEG, PNG, or WebP images (max 5 MB).
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    # Validate file type
    allowed_types = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
    content_type = file.content_type or ""
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type '{content_type}'. Allowed: JPEG, PNG, WebP.",
        )

    # Read file bytes
    content = await file.read()

    # Enforce 5 MB limit
    max_bytes = 5 * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(status_code=400, detail="Logo image must be under 5 MB.")

    # Build a unique R2 key
    ext = (file.filename or "logo.jpg").rsplit(".", 1)[-1].lower()
    if ext not in ("jpg", "jpeg", "png", "webp"):
        ext = "jpg"
    unique_id = uuid.uuid4().hex[:12]
    file_key = f"{username}/logos/shop_logo_{unique_id}.{ext}"

    try:
        from services.storage import get_storage_client
        storage = get_storage_client()

        success = storage.upload_file(
            file_data=content,
            bucket=r2_bucket,
            key=file_key,
            content_type=content_type or "image/jpeg",
        )
        if not success:
            raise HTTPException(status_code=500, detail="Failed to upload logo to storage.")

        public_url = storage.get_public_url(r2_bucket, file_key)
        if not public_url:
            raise HTTPException(status_code=500, detail="Logo uploaded but public URL unavailable.")

        logger.info(f"Shop logo uploaded for {username}: {public_url}")
        return {"logo_url": public_url}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading shop logo for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload shop logo.")

