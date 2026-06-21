import logging
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, HTMLResponse

import config

# Configure logging
# nothing

# Create console handler with explicit flushing
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)

# Set format
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
# nothing
# Configure root logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[console_handler],
    force=True  # Force reconfiguration even if logging was already configured
)

# Force flush after each log
class FlushingHandler(logging.StreamHandler):
    def emit(self, record):
        super().emit(record)
        self.flush()

# Replace with flushing handler
root_logger = logging.getLogger()
root_logger.handlers.clear()
flushing_handler = FlushingHandler(sys.stdout)
flushing_handler.setFormatter(formatter)
flushing_handler.setLevel(logging.INFO)
root_logger.addHandler(flushing_handler)
root_logger.setLevel(logging.INFO)

# Suppress httpx INFO logs (too verbose - thousands of Supabase API calls)
logging.getLogger('httpx').setLevel(logging.WARNING)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager"""
    logger.info("SnapKhata API starting up...")
    logger.info(f"CORS origins: {config.settings.cors_origins}")

    # ── Orphaned task cleanup ─────────────────────────────────────────────────
    # Any task still in 'processing' or 'queued' when the server starts was
    # killed by a previous reload/crash. Mark them as 'failed' immediately so
    # clients stop polling and show an error instead of looping forever.
    try:
        from database import get_database_client
        from datetime import datetime, timezone
        db = get_database_client()
        failed_update = {
            "status": "failed",
            "message": "Processing was interrupted by a server restart. Please re-upload.",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        for table in ("upload_tasks", "recalculation_tasks"):
            try:
                # Mark stuck 'processing' tasks
                db.client.table(table).update(failed_update).eq("status", "processing").execute()
                # Mark stuck 'queued' tasks
                db.client.table(table).update(failed_update).eq("status", "queued").execute()
            except Exception as tbl_err:
                logger.warning(f"Could not clean orphaned tasks in '{table}': {tbl_err}")
        logger.info("Orphaned task cleanup complete")
    except Exception as e:
        logger.warning(f"Orphaned task cleanup skipped (non-fatal): {e}")

    yield
    
    logger.info("SnapKhata API shutting down...")

# Create FastAPI app
app = FastAPI(
    title="SnapKhata API",
    description="Backend API for Invoice Processing and Management",
    version="2.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],  # Allow browser to read this header for file downloads
)

# ── Validation Error Handler for Cloud Tasks ──────────────────────
# Cloud Tasks retries on 4xx/5xx responses. If a stale task sends a
# payload that fails Pydantic validation (422), Cloud Tasks would
# retry it FOREVER.  This handler returns 200 for the internal
# webhook endpoint so Cloud Tasks considers the task complete and
# stops retrying.
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    if "/internal/" in str(request.url):
        logger.error(f"[VALIDATION-ERROR] Cloud Tasks sent invalid payload to {request.url}")
        logger.error(f"[VALIDATION-ERROR] Details: {exc.errors()}")
        try:
            body = await request.body()
            logger.error(f"[VALIDATION-ERROR] Raw body: {body.decode('utf-8', errors='replace')[:2000]}")
        except Exception:
            pass
        # Return 200 so Cloud Tasks stops retrying this malformed payload
        return JSONResponse(
            status_code=200,
            content={
                "status": "error",
                "message": "Validation failed — payload rejected. Task will not be retried.",
                "errors": [str(e) for e in exc.errors()[:5]]
            }
        )
    # For all other endpoints, return the standard 422 response
    # Note: exc.errors() can contain non-serializable objects (e.g. ValueError in ctx)
    # so we must sanitize them before passing to JSONResponse.
    def _safe_errors(errors):
        safe = []
        for e in errors:
            safe_e = {}
            for k, v in e.items():
                if k == "ctx" and isinstance(v, dict):
                    safe_e[k] = {ck: str(cv) for ck, cv in v.items()}
                else:
                    try:
                        import json
                        json.dumps(v)
                        safe_e[k] = v
                    except (TypeError, ValueError):
                        safe_e[k] = str(v)
            safe.append(safe_e)
        return safe

    return JSONResponse(
        status_code=422,
        content={"detail": _safe_errors(exc.errors())}
    )

# Startup Error Handling
try:
    # Import routers
    from routes import auth, upload, invoices, review, verified, config_api, inventory, inventory_mapping, vendor_mapping_routes, stock_routes, stock_mapping_upload_routes, dashboard_routes, purchase_order_routes, public_routes, udhar, vendor_ledgers, download, register, usage_routes, paginated_api, galla_routes, shop_profile, item_catalogue, voice, pdf_routes
except Exception as e:
    import traceback
    print("CRITICAL STARTUP ERROR: Failed to import routers", flush=True)
    traceback.print_exc()
    raise e

# Register routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(register.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(config_api.router, prefix="/api", tags=["Configuration"])
app.include_router(paginated_api.router, prefix="/api", tags=["Paginated Data"])
app.include_router(dashboard_routes.router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(upload.router, prefix="/api/upload", tags=["Upload & Processing"])
app.include_router(inventory.router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(inventory_mapping.router, prefix="/api/inventory-mapping", tags=["Inventory Mapping"])
app.include_router(vendor_mapping_routes.router, prefix="/api/vendor-mapping", tags=[" Vendor Mapping"])
app.include_router(stock_routes.router, prefix="/api/stock", tags=["Stock Levels"])
app.include_router(stock_mapping_upload_routes.router, prefix="/api/stock/mapping-sheets", tags=["Stock Mapping Upload"])
app.include_router(purchase_order_routes.router, prefix="/api/purchase-orders", tags=["Purchase Orders"])
app.include_router(invoices.router, prefix="/api/invoices", tags=["Invoices"])
app.include_router(review.router, prefix="/api/review", tags=["Review"])
app.include_router(verified.router, prefix="/api/verified", tags=["Verified Invoices"])
app.include_router(udhar.router, prefix="/api/udhar", tags=["Udhar Tracking"])
app.include_router(vendor_ledgers.router, prefix="/api/vendor-ledgers", tags=["Vendor Ledgers"])
app.include_router(galla_routes.router, prefix="/api/galla", tags=["Galla"])
app.include_router(pdf_routes.router, prefix="/api/public", tags=["Public PDF"])
app.include_router(public_routes.router, prefix="/api/public", tags=["Public"])
app.include_router(download.router, prefix="/api", tags=["Download"])
app.include_router(usage_routes.router, prefix="/api/usage", tags=["Usage Metrics"])
app.include_router(shop_profile.router, prefix="/api", tags=["Shop Profile"])
app.include_router(item_catalogue.router, prefix="/api/items/catalogue", tags=["Item Catalogue"])
app.include_router(voice.router, prefix="/api/voice", tags=["Voice"])


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "SnapKhata API",
        "version": "2.0.0",
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.get("/privacy", response_class=HTMLResponse)
async def privacy_policy():
    """Privacy Policy endpoint"""
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - SnapKhata</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #1e293b;
            background-color: #f8fafc;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 800px;
            margin: 40px auto;
            padding: 40px;
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
        }
        h1 {
            color: #0f172a;
            font-size: 2.25rem;
            margin-top: 0;
            border-bottom: 2px solid #e2e8f0;
            padding-bottom: 12px;
        }
        h2 {
            color: #1e3a8a;
            font-size: 1.5rem;
            margin-top: 32px;
        }
        p, li {
            font-size: 1rem;
            color: #334155;
        }
        ul {
            padding-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
        .footer {
            margin-top: 40px;
            border-top: 1px solid #e2e8f0;
            padding-top: 20px;
            font-size: 0.875rem;
            color: #64748b;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Privacy Policy</h1>
        <p><strong>Effective Date: June 21, 2026</strong></p>
        <p>SnapKhata ("we", "our", or "us") operates the SnapKhata mobile application. This Privacy Policy informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service and the choices you have associated with that data.</p>
        
        <h2>1. Information Collection and Use</h2>
        <p>We collect several different types of information for various purposes to provide and improve our Service to you.</p>
        
        <h3>Types of Data Collected:</h3>
        <ul>
            <li><strong>Personal Data:</strong> While using our Service, we may ask you to provide us with certain personally identifiable information that can be used to contact or identify you, including your name, email address, and billing information.</li>
            <li><strong>Voice and Audio Data:</strong> The application requests access to the device microphone to enable speech-to-text recording functionality. Voice and audio inputs are transiently processed to translate speech into ledger text entries.</li>
            <li><strong>Files and Images (Camera/Storage):</strong> We request camera and storage permissions to upload invoice images and documents for Optical Character Recognition (OCR) invoice parsing.</li>
        </ul>

        <h2>2. Use of Data</h2>
        <p>SnapKhata uses the collected data for various purposes:</p>
        <ul>
            <li>To provide and maintain our Service.</li>
            <li>To notify you about changes to our Service.</li>
            <li>To allow you to participate in interactive features of our Service when you choose to do so.</li>
            <li>To provide customer support.</li>
            <li>To gather analysis or valuable information so that we can improve our Service.</li>
            <li>To monitor the usage of our Service and detect, prevent, and address technical issues.</li>
        </ul>

        <h2>3. Data Transfer and Security</h2>
        <p>Your information, including Personal Data, is processed securely. We adopt appropriate security and encryption measures to prevent unauthorized access, alteration, disclosure, or destruction of your personal information.</p>

        <h2>4. Contact Us</h2>
        <p>If you have any questions about this Privacy Policy, please contact us:</p>
        <ul>
            <li>By email: support@snapkhata.com</li>
        </ul>
        
        <div class="footer">
            &copy; 2026 SnapKhata. All rights reserved.
        </div>
    </div>
</body>
</html>
"""


@app.get("/api/db-check")
async def db_check():
    """Check database connection explicitly"""
    try:
        from database import get_database_client
        import os
        
        # Check env vars (redacted)
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        
        db = get_database_client()
        # Try a simple query
        _ = db.client.table("users").select("count", count="exact").limit(1).execute()
        
        return {
            "status": "connected",
            "supabase_url_configured": bool(url),
            "supabase_key_configured": bool(key),
            "response": "OK"
        }
    except Exception as e:
        import traceback
        return {
            "status": "error",
            "detail": str(e),
            "traceback": traceback.format_exc()
        }




if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        log_level="info",
        access_log=True  # Enable access logging
    )