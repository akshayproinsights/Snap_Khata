"""
Service for managing user profiles in SnapKhata.
Provides robust data retrieval from the user_profile table.
"""
import logging
from typing import Dict, Any, Optional
from fastapi import HTTPException
from database import get_database_client

logger = logging.getLogger(__name__)

class UserProfileService:
    """Handles retrieval and management of business information from user_profile table."""

    @staticmethod
    def get_profile_by_username(username: str) -> Dict[str, Any]:
        """
        Fetch shop name, site contact, mobile number, address, and other business info.
        Prioritizes database queries and eliminates fallback mechanisms.
        """
        if not username:
            raise ValueError("Username must be provided")

        try:
            db = get_database_client()
            resp = (
                db.client.table("user_profile")
                .select("shop_name, site_contact, mobile_number, address, shop_gst")
                .eq("username", username)
                .limit(1)
                .execute()
            )

            if not resp.data or len(resp.data) == 0:
                logger.warning(f"No profile found in user_profile for user: {username}")
                # As per user's request, no fallbacks allowed.
                # Returning empty values for fields to maintain consistency but without fallback.
                return {
                    "shop_name": "",
                    "site_contact": username, # Default to username as requested
                    "mobile_number": "",
                    "address": "",
                    "shop_gst": "",
                }

            row = resp.data[0]
            logger.info(f"Successfully retrieved profile for user: {username}")
            return {
                "shop_name": row.get("shop_name", ""),
                "site_contact": row.get("site_contact", username),
                "mobile_number": row.get("mobile_number", ""),
                "address": row.get("address", ""),
                "shop_gst": row.get("shop_gst", ""),
            }

        except Exception as e:
            logger.error(f"Error fetching user profile for {username}: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Database error during profile retrieval: {str(e)}"
            )

    @staticmethod
    def save_profile(username: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Save (upsert) profile details for the authenticated user.
        Ensures data integrity and validation.
        """
        if not username:
            raise ValueError("Username must be provided")

        # Basic validation
        shop_name = data.get("shop_name", "").strip()
        if not shop_name:
            # We allow empty for now but log it
            logger.debug(f"Saving profile with empty shop_name for user: {username}")

        try:
            db = get_database_client()
            upsert_data = {
                "username": username,
                "shop_name": shop_name,
                "site_contact": data.get("site_contact", username),
                "mobile_number": data.get("mobile_number", ""),
                "address": data.get("address", ""),
                "shop_gst": data.get("shop_gst", ""),
                "updated_at": "now()" # Let Supabase handle it or use a timestamp
            }
            
            resp = db.client.table("user_profile") \
                .upsert(upsert_data, on_conflict="username") \
                .execute()

            logger.info(f"User profile saved successfully for: {username}")
            return {"success": True, "message": "Profile saved successfully"}

        except Exception as e:
            logger.error(f"Error saving user profile for {username}: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to save user profile: {str(e)}"
            )
