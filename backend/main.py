"""
Main FastAPI application.
Handles routing, middleware, and application lifecycle.
"""
print("SnapKhata Backend is starting......Final Doneee..")
# Final check done yep done yes git yep done api done yesss finally
# Initial deployment trigger done yeah d addddd
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
import logging

import config

# Configure logging
import sys

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

# Create FastAPI app
app = FastAPI(
    title="SnapKhata API",
    description="Backend API for Invoice Processing and Management",
    version="2.0.0"
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
    from routes import auth, upload, invoices, review, verified, config_api, inventory, inventory_mapping, vendor_mapping_routes, stock_routes, stock_mapping_upload_routes, dashboard_routes, purchase_order_routes, public_routes, udhar, vendor_ledgers, download, register, usage_routes
except Exception as e:
    import traceback
    print("CRITICAL STARTUP ERROR: Failed to import routers", flush=True)
    traceback.print_exc()
    raise e

# Register routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(register.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(config_api.router, prefix="/api", tags=["Configuration"])
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
app.include_router(public_routes.router, prefix="/api/public", tags=["Public"])
app.include_router(download.router, prefix="/api", tags=["Download"])
app.include_router(usage_routes.router, prefix="/api/usage", tags=["Usage Metrics"])


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


@app.on_event("startup")
async def startup_event():
    """Application startup"""
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


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown"""
    logger.info("SnapKhata API shutting down...")


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