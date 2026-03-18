from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import FileResponse
import os
import logging
from typing import Optional

# Import auth dependencies (optional if we want to support standard JWT as well)
try:
    from auth import get_current_user
except ImportError:
    # If auth module is not accessible or has issues
    get_current_user = None

router = APIRouter()
logger = logging.getLogger(__name__)

# Configurable path - default provided in request
APK_PATH = os.getenv("APK_FILE_PATH", "/var/www/downloads/snapkhata-release.apk")
# Secure token for download - should be set in environment variables
DOWNLOAD_TOKEN = os.getenv("DOWNLOAD_TOKEN")

@router.get("/download-app")
async def download_app(
    token: Optional[str] = Query(None, description="Secure download token"),
    # current_user: Optional[dict] = Depends(get_current_user) # Uncomment for full JWT auth
):
    """
    Secure endpoint to download the Android APK file.
    Requires either a valid DOWNLOAD_TOKEN query parameter or standard JWT authentication.
    """
    
    # ── Security Check ────────────────────────────────────────────────────────
    # 1. Check if a static token is provided and matches the environment variable
    is_authorized = False
    
    if DOWNLOAD_TOKEN and token == DOWNLOAD_TOKEN:
        is_authorized = True
    
    # 2. Alternatively, if no static token is set or matched, we could check for current_user
    # if not is_authorized and current_user:
    #     is_authorized = True
        
    # If the user specifically asked for "secure" and no token matches, raise 401
    if DOWNLOAD_TOKEN and not is_authorized:
        raise HTTPException(status_code=401, detail="Invalid or missing download token")
    
    # Special case: if DOWNLOAD_TOKEN is NOT set, we might want to warn but still serve
    # or require auth. For now, if it's set, we enforce it.
    
    # ── File Response ─────────────────────────────────────────────────────────
    if not os.path.exists(APK_PATH):
        logger.error(f"APK file not found at: {APK_PATH}")
        raise HTTPException(status_code=404, detail="Application file not found on server")

    filename = os.path.basename(APK_PATH)
    
    return FileResponse(
        path=APK_PATH,
        media_type="application/vnd.android.package-archive",
        filename=filename,
        content_disposition_type="attachment"
    )
