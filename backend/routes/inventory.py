"""Inventory upload and processing routes"""
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime
import uuid
import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from fastapi.responses import StreamingResponse
import pandas as pd

from auth import get_current_user, get_current_user_r2_bucket
from services.storage import get_storage_client
from utils.image_optimizer import optimize_image_for_gemini, should_optimize_image, validate_image_quality
from config import get_purchases_folder

router = APIRouter()
logger = logging.getLogger(__name__)

# Thread pool for blocking operations (Optimized for high-load: 50 concurrent tasks)
# Configurable via environment variable
executor = ThreadPoolExecutor(max_workers=int(os.getenv('INVENTORY_MAX_WORKERS', '50')))

# In-memory storage REMOVED - using database table 'upload_tasks'
# inventory_processing_status: Dict[str, Dict[str, Any]] = {}


def _resolve_receipt_link(receipt_link: str) -> str:
    """
    Convert internal r2://bucket/key URLs to proper HTTPS public URLs.
    If the URL is already a valid HTTP/HTTPS URL it is returned unchanged.
    """
    if not receipt_link or not receipt_link.startswith('r2://'):
        return receipt_link
    try:
        path = receipt_link[5:]  # strip 'r2://'
        parts = path.split('/', 1)
        if len(parts) != 2:
            logger.warning(f"Cannot parse r2:// URL '{receipt_link}' — returning as-is")
            return receipt_link
        bucket, key = parts[0], parts[1]
        storage = get_storage_client()
        public_url = storage.get_public_url(bucket, key)
        if public_url:
            return public_url
    except Exception as exc:
        logger.error(f"Error resolving receipt_link '{receipt_link}': {exc}")
    return receipt_link
class InventoryUploadResponse(BaseModel):
    """Inventory upload response model"""
    success: bool
    uploaded_files: List[str]
    message: str


class InventoryProcessRequest(BaseModel):
    """Process inventory request model"""
    file_keys: List[str]
    force_upload: bool = True  # If True, bypass duplicate checking and delete old duplicates


class InventoryProcessResponse(BaseModel):
    """Process inventory response model"""
    task_id: str
    status: str
    message: str


class InventoryProcessStatusResponse(BaseModel):
    """Process status response model"""
    task_id: str
    status: str
    progress: Dict[str, Any]
    message: str
    duplicates: Optional[List[Dict[str, Any]]] = []  # Add duplicates field
    uploaded_r2_keys: List[str] = []  # CRITICAL: R2 keys for frontend


class InventoryInvoiceVerifyRequest(BaseModel):
    """Inventory invoice verify request"""
    invoice_number: str
    vendor_name: str
    invoice_date: str
    payment_mode: Optional[str] = "Cash"
    payment_date: Optional[str] = None
    amount_paid: Optional[float] = 0.0
    balance_owed: Optional[float] = 0.0
    vendor_notes: Optional[str] = None
    item_ids: List[int]
    final_total: Optional[float] = None
    adjustments: Optional[List[Dict[str, Any]]] = None
    car_number: Optional[str] = None
    vehicle_number: Optional[str] = None
    extra_fields: Optional[Dict[str, Any]] = None
    odometer: Optional[str] = None
    taxable_row_ids: Optional[List[int]] = None


class InventoryUploadHistoryItem(BaseModel):
    date: str
    count: int
    invoice_ids: List[str]

class InventoryUploadHistorySummary(BaseModel):
    last_active_date: Optional[str] = None
    last_invoice_number: Optional[str] = None
    status: str = "caught_up"

class InventoryUploadHistoryResponse(BaseModel):
    summary: InventoryUploadHistorySummary
    history: List[InventoryUploadHistoryItem]


@router.get("/upload-history", response_model=InventoryUploadHistoryResponse)
def get_inventory_upload_history(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get inventory upload history and status for the "Resume" banner.
    Returns:
    - Last active date and invoice number
    - Recent history grouped by date (last 7 entries)
    """
    try:
        username = current_user['username']
        from database import get_database_client
        db = get_database_client()
        supabase = db.client
        
        # 1. Fetch recent inventory items for history (limit 100 to process in memory)
        # ORDER BY invoice_date DESC to get most recent invoices by date
        response = supabase.table('inventory_items') \
            .select('invoice_date, invoice_number, created_at') \
            .eq('username', username) \
            .order('invoice_date', desc=True) \
            .limit(100) \
            .execute()
            
        items = response.data if response.data else []
        
        if not items:
            return {
                "summary": {
                    "last_active_date": None,
                    "last_invoice_number": None,
                    "status": "no_uploads"
                },
                "history": []
            }
            
        # 2. Process for Summary (Latest Upload)
        # Use invoice_date (date field) - this is what users care about
        # ALSO: Within the same date, pick the invoice with the HIGHEST invoice number
        latest_invoice_date = items[0].get('invoice_date', '')  # Latest date
        
        # Find all invoices for this date and pick the one with max invoice_number
        invoices_on_latest_date = [item for item in items if item.get('invoice_date') == latest_invoice_date]
        
        # Try to convert invoice_number to int for comparison, fallback to string comparison
        def get_invoice_num(item):
            num = item.get('invoice_number', '') or ''
            # Try to extract numeric part for comparison
            try:
                # If it's purely numeric, use int
                return int(num)
            except (ValueError, TypeError):
                # If it contains letters, just use string comparison
                return num
        
        latest_item = max(invoices_on_latest_date, key=get_invoice_num)
        
        
        # 3. Process for History (Group by Date)
        # Group by the 'invoice_date' field
        history_map = {}
        
        for item in items:
            date_str = item.get('invoice_date') or 'Unknown Date'
            invoice_num = item.get('invoice_number') or 'N/A'
            
            if date_str not in history_map:
                history_map[date_str] = {
                    "date": date_str,
                    "count": 0,
                    "invoice_ids": [],
                    "seen_invoices": set()  # Track unique invoices
                }
            
            # Only increment count once per unique invoice number
            if invoice_num not in history_map[date_str]["seen_invoices"]:
                history_map[date_str]["count"] += 1
                history_map[date_str]["seen_invoices"].add(invoice_num)
                
                # Only show first 10 unique invoices per day in the chip list
                if len(history_map[date_str]["invoice_ids"]) < 10:
                    history_map[date_str]["invoice_ids"].append(f"#{invoice_num}")
                
        # Convert map to list and sort by date descending
        history_list = sorted(
            history_map.values(), 
            key=lambda x: x['date'], 
            reverse=True
        )
        
        # Format history items (remove seen_invoices set before returning)
        final_history = []
        for item in history_list:
             # Remove the tracking set before creating the response model
             item.pop('seen_invoices', None)
             final_history.append(InventoryUploadHistoryItem(**item))
             
        return {
            "summary": {
                "last_active_date": latest_invoice_date,  # Use invoice date
                "last_invoice_number": latest_item.get('invoice_number'),
                "status": "caught_up"
            },
            "history": final_history[:7] # Return last 7 active dates
        }
        
    except Exception as e:
        print(f"Error fetching inventory upload history: {e}")
        # Return empty structure on error to avoid breaking UI
        return {
            "summary": {"status": "error"},
            "history": []
        }


@router.get("/upload-urls")
async def get_inventory_upload_urls(
    count: int = 1,
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    FIX-2: Return pre-signed R2 PUT URLs so the mobile app can upload images
    directly to Cloudflare R2, bypassing the Python server entirely.

    The mobile app calls this first to get N signed URLs, then uploads each
    image with a plain HTTP PUT request directly to R2.
    After all uploads complete, the app calls /api/inventory/process with
    the returned R2 keys.

    Query params:
      count   - number of files to upload (default 1, max 20)
    """
    if count < 1 or count > 20:
        raise HTTPException(status_code=400, detail="count must be between 1 and 20")

    username = current_user.get("username", "user")
    inventory_folder = get_purchases_folder(username)

    try:
        import boto3
        from botocore.client import Config as BotocoreConfig

        r2_account_id = os.getenv("CLOUDFLARE_R2_ACCOUNT_ID") or os.getenv("R2_ACCOUNT_ID")
        r2_access_key  = os.getenv("CLOUDFLARE_R2_ACCESS_KEY_ID") or os.getenv("R2_ACCESS_KEY_ID")
        r2_secret_key  = os.getenv("CLOUDFLARE_R2_SECRET_ACCESS_KEY") or os.getenv("R2_SECRET_ACCESS_KEY")

        if not all([r2_account_id, r2_access_key, r2_secret_key]):
            raise HTTPException(status_code=500, detail="R2 credentials not configured")

        s3 = boto3.client(
            "s3",
            endpoint_url=f"https://{r2_account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=r2_access_key,
            aws_secret_access_key=r2_secret_key,
            config=BotocoreConfig(signature_version="s3v4"),
            region_name="auto",
        )

        upload_slots = []
        for _ in range(count):
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            unique_id = uuid.uuid4().hex[:8]
            file_key  = f"{inventory_folder}{timestamp}_{unique_id}.jpg"

            presigned_url = s3.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": r2_bucket,
                    "Key": file_key,
                    "ContentType": "image/jpeg",
                },
                ExpiresIn=300,  # 5 minutes — plenty for compression + upload
            )
            upload_slots.append({"file_key": file_key, "upload_url": presigned_url})

        logger.info(f"Generated {count} pre-signed upload URLs for {username}")
        return {"success": True, "upload_slots": upload_slots}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating pre-signed URLs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload", response_model=InventoryUploadResponse)
async def upload_inventory_files(
    files: List[UploadFile] = File(...),
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    Upload inventory files to R2 storage CONCURRENTLY.
    All files are uploaded to R2 in parallel (asyncio.gather),
    reducing upload time dramatically for batches.
    """
    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded")
    
    username = current_user.get("username", "user")
    logger.info(f"Received {len(files)} files for inventory upload from {username}")
    
    try:
        inventory_folder = get_purchases_folder(username)
        
        # Read all file bytes into memory first (async, fast)
        file_data_list = []
        for file in files:
            content = await file.read()
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            unique_id = uuid.uuid4().hex[:6]
            # Ensure file has an extension, default to .jpg since our optimizer always outputs JPEG
            filename = file.filename or ""
            if not filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                filename = f"{filename}.jpg"
            
            file_key = f"{inventory_folder}{timestamp}_{unique_id}_{filename}"
            
            file_data_list.append({
                'content': content,
                'filename': filename,
                'file_key': file_key
            })
        
        logger.info(f"Starting PARALLEL upload of {len(file_data_list)} inventory files for {username}")
        
        # Upload all files in parallel — each runs in the thread pool
        semaphore = asyncio.Semaphore(10)
        loop = asyncio.get_event_loop()

        async def upload_one(file_data: Dict[str, Any]) -> Optional[str]:
            async with semaphore:
                return await loop.run_in_executor(
                    executor,
                    upload_single_inventory_file_sync,
                    file_data['content'],
                    file_data['filename'],
                    username,
                    r2_bucket,
                    file_data['file_key']
                )

        results = await asyncio.gather(*[upload_one(fd) for fd in file_data_list])
        uploaded_keys = [key for key in results if key is not None]
        
        if not uploaded_keys:
             raise HTTPException(status_code=500, detail="Failed to upload any files")

        logger.info(f"Successfully uploaded {len(uploaded_keys)}/{len(file_data_list)} inventory files in parallel")
        
        return {
            "success": True,
            "uploaded_files": uploaded_keys,
            "message": f"Successfully uploaded {len(uploaded_keys)} file(s)"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in upload_inventory_files: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


# process_uploads_batch_sync is no longer used — upload_inventory_files now uses
# asyncio.gather() for parallel uploads. Kept as a no-op stub for safety.
def process_uploads_batch_sync(
    file_data_list: List[Dict[str, Any]],
    username: str,
    r2_bucket: str
) -> List[str]:
    """Deprecated: parallel upload is now done directly in upload_inventory_files endpoint."""
    logger.warning("process_uploads_batch_sync called — this is deprecated. Use parallel upload instead.")
    return []


def upload_single_inventory_file_sync(
    content: bytes,
    filename: str,
    username: str,
    r2_bucket: str,
    file_key: str  # NEW: Accept pre-generated key
) -> Optional[str]:
    """
    Synchronous helper for single inventory file upload - runs in background task.
    Contains blocking operations: image validation, optimization, and R2 upload.
    
    Args:
        content: File content bytes
        filename: Original filename (for logging)
        username: Username (for logging)
        r2_bucket: R2 bucket name
        file_key: Pre-generated R2 key (path)
    
    Returns:
        File key if successful, None otherwise
    """
    try:
        storage = get_storage_client()
        
        # Validate image quality
        validation = validate_image_quality(content)
        if not validation['is_acceptable']:
            for warning in validation['warnings']:
                logger.warning(f"{filename}: {warning}")
        
        # Optimize image before upload
        if should_optimize_image(content):
            logger.info(f"Optimizing inventory image: {filename}")
            optimized_content, metadata = optimize_image_for_gemini(content)
            
            logger.info(f"Optimization results for {filename}:")
            logger.info(f"  Original: {metadata['original_size_kb']}KB")
            logger.info(f"  Optimized: {metadata['optimized_size_kb']}KB")
            logger.info(f"  Compression: {metadata['compression_ratio']}% reduction")
            
            content = optimized_content
        else:
            logger.info(f"Skipping optimization for {filename}")
        
        # Determine content type (always JPEG after optimization)
        content_type = "image/jpeg"
        
        # Upload to R2 using pre-generated key
        success = storage.upload_file(
            file_data=content,
            bucket=r2_bucket,
            key=file_key,
            content_type=content_type
        )
        
        if success:
            logger.info(f"Uploaded inventory file: {file_key}")
            return file_key
        else:
            logger.error(f"Failed to upload inventory file: {filename}")
            return None
            
    except Exception as e:
        logger.error(f"Error uploading inventory file {filename}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return None


@router.post("/process", response_model=InventoryProcessResponse)
async def process_inventory(
    request: InventoryProcessRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Trigger inventory processing in thread pool
    """
    logger.info(f"Received inventory process request for {len(request.file_keys)} files")
    task_id = str(uuid.uuid4())
    username = current_user.get("username", "user")

    # Get r2_bucket from user config
    r2_bucket = current_user.get("r2_bucket")
    if not r2_bucket:
        raise HTTPException(status_code=400, detail="No r2_bucket configured for user")

    # ── REQUEST-LEVEL IDEMPOTENCY GUARD ──────────────────────────────────────
    # Same guard as the sales /process-files endpoint. Prevents the same R2 keys
    # being sent to Gemini twice if the frontend retries before the first task
    # has written its results to the DB.
    if not request.force_upload:
        try:
            from database import get_database_client as _get_db
            _guard_db = _get_db()
            _active = _guard_db.client.table("upload_tasks") \
                .select("task_id, status, uploaded_r2_keys, created_at") \
                .eq("username", username) \
                .in_("status", ["queued", "processing", "uploading"]) \
                .eq("task_type", "inventory") \
                .order("created_at", desc=True) \
                .limit(10) \
                .execute()

            incoming_keys = set(request.file_keys)
            for active_task in (_active.data or []):
                existing_keys = set(active_task.get("uploaded_r2_keys") or [])
                overlap = incoming_keys & existing_keys
                if overlap:
                    existing_task_id = active_task.get("task_id")
                    logger.warning(
                        f"[IDEMPOTENCY GUARD] Inventory duplicate submission blocked for {username}. "
                        f"Overlapping keys: {overlap}. Existing active task: {existing_task_id}"
                    )
                    raise HTTPException(
                        status_code=409,
                        detail={
                            "code": "DUPLICATE_SUBMISSION",
                            "message": "These files are already being processed. Please wait for the current task to complete.",
                            "existing_task_id": existing_task_id,
                        }
                    )
        except HTTPException:
            raise
        except Exception as guard_err:
            logger.warning(f"[IDEMPOTENCY GUARD] Inventory check failed (non-fatal), proceeding: {guard_err}")
    # ── END IDEMPOTENCY GUARD ─────────────────────────────────────────────────

    # ── FILE PATH VALIDATION ──────────────────────────────────────────────────
    # CRITICAL: Ensure all files are from the inventory/ folder, not sales/ folder
    # This prevents accidental routing of supplier bills to customer receipts
    expected_prefix = get_purchases_folder(username)  # e.g., "akshaykh/inventory/"
    sales_prefix = f"{username}/sales/"
    
    invalid_files = []
    for file_key in request.file_keys:
        if not file_key.startswith(expected_prefix):
            invalid_files.append(file_key)
            # Log warning if file is in sales folder
            if file_key.startswith(sales_prefix):
                logger.error(f"⚠️ ROUTING ERROR: File {file_key} is in SALES folder but being processed as INVENTORY. This indicates a frontend/mobile routing issue!")
    
    if invalid_files:
        logger.error(f"Rejecting inventory process request: {len(invalid_files)}/{len(request.file_keys)} files are not from inventory folder")
        logger.error(f"Expected prefix: {expected_prefix}")
        logger.error(f"Invalid files: {invalid_files}")
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file paths for inventory processing. Expected files from '{expected_prefix}' folder. "
                   f"Please check that you used the 'Supplier/Inventory' upload, not 'Sales' upload. "
                   f"Invalid: {', '.join(invalid_files[:3])}"
        )
    # ── END FILE PATH VALIDATION ──────────────────────────────────────────────

    # Initialize status in DATABASE
    initial_status = {
        "task_id": task_id,
        "username": current_user.get("username", "user"),
        "status": "queued",
        "task_type": "inventory", # NEW: Distinguish task type
        "message": "Processing queued",
        "progress": {
            "total": len(request.file_keys),
            "processed": 0,
            "failed": 0
        },
        "duplicates": [],
        "errors": [],
        "current_file": "",
        "current_index": 0,
        "uploaded_r2_keys": [],
        "created_at": datetime.utcnow().isoformat()
    }
    
    try:
        from database import get_database_client
        db = get_database_client()
        db.insert("upload_tasks", initial_status)
        logger.info(f"Created inventory task {task_id} for user {current_user.get('username')} in database")
    except Exception as e:
        logger.error(f"Failed to create inventory task in DB: {e}")
        # convert to HTTP 500
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    # Run in thread pool
    loop = asyncio.get_event_loop()
    loop.run_in_executor(
        executor,
        process_inventory_sync,
        task_id,
        request.file_keys,
        r2_bucket,
        current_user.get("username", "user"),
        request.force_upload  # Pass force_upload parameter
    )
    
    return {
        "task_id": task_id,
        "status": "queued",
        "message": f"Processing {len(request.file_keys)} inventory file(s) in background"
    }


@router.get("/recent-task", response_model=InventoryProcessStatusResponse)
async def get_recent_inventory_task(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get the most recent upload task for the current user.
    Useful for resuming progress bars if the user refreshes the page.
    IMPORTANT: This route MUST be defined before /status/{task_id} to prevent
    FastAPI from matching 'recent-task' as the task_id path parameter.
    """
    try:
        from database import get_database_client
        db = get_database_client()
        
        # Fetch most recent task
        response = db.client.table("upload_tasks")\
            .select("*")\
            .eq("username", current_user.get("username"))\
            .eq("task_type", "inventory")\
            .order("created_at", desc=True)\
            .limit(1)\
            .execute()
            
        if not response.data or len(response.data) == 0:
            raise HTTPException(status_code=404, detail="No recent tasks found")
            
        status_record = response.data[0]
        
        return {
            "task_id": status_record.get("task_id"),
            "status": status_record.get("status", "unknown"),
            "progress": status_record.get("progress", {}),
            "message": status_record.get("message", ""),
            "duplicates": status_record.get("duplicates", []),
            "uploaded_r2_keys": status_record.get("uploaded_r2_keys", [])
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching recent inventory task: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch recent task: {str(e)}")


@router.get("/status/{task_id}", response_model=InventoryProcessStatusResponse)
async def get_inventory_process_status(
    task_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get processing status for an inventory task from DATABASE.
    """
    try:
        from database import get_database_client
        db = get_database_client()
        # Query task by ID
        response = db.query("upload_tasks").eq("task_id", task_id).execute()
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(status_code=404, detail="Task not found")
        
        status_record = response.data[0]
        
        # Verify ownership (optional but good practice)
        if status_record.get("username") != current_user.get("username") and current_user.get("role") != "admin":
             # Silently return 404 or just pass if we trust UUID security
             pass 

        return {
            "task_id": status_record.get("task_id"),
            "status": status_record.get("status", "unknown"),
            "progress": status_record.get("progress", {}),
            "message": status_record.get("message", ""),
            "duplicates": status_record.get("duplicates", []),
            "uploaded_r2_keys": status_record.get("uploaded_r2_keys", [])
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching inventory task status {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch status: {str(e)}")


def _build_completion_message(processed: int, skipped: int, failed: int) -> str:
    """Build a human-readable completion message."""
    parts = []
    if processed > 0:
        parts.append(f"{processed} invoice{'s' if processed != 1 else ''} processed")
    if failed > 0:
        parts.append(f"{failed} failed")
    if not parts:
        return "No invoices were processed"
    return ", ".join(parts)


def process_inventory_sync(
    task_id: str,
    file_keys: List[str],  # These are R2 keys now
    r2_bucket: str,
    username: str,
    force_upload: bool = False
):
    """
    Synchronous background task to process inventory
    1. Process with Gemini (files already in R2)
    """
    
    logger.info("=== INVENTORY PROCESSING STARTED ===")
    logger.info(f"Task ID: {task_id}")
    logger.info(f"Files: {len(file_keys)} R2 keys")
    logger.info(f"User: {username}")
    
    # Helper to update DB status
    def update_db_status(status_update: Dict[str, Any]):
        try:
            from database import get_database_client
            db = get_database_client()
            status_update["updated_at"] = datetime.utcnow().isoformat()
            db.update("upload_tasks", status_update, {"task_id": task_id})
        except Exception as e:
            logger.error(f"Failed to update inventory task status in DB: {e}")

    # Initialize current status dict for local updates (efficiency)
    current_status = {
        "progress": {
            "total": len(file_keys),
            "processed": 0,
            "failed": 0
        }
    }

    try:
        # Files are already in R2
        r2_file_keys = file_keys
        
        # Phase 2: Process inventory
        logger.info("Phase 2: Processing inventory with AI...")
        
        update_db_status({
            "status": "processing",
            "message": "Processing inventory items...",
            "progress": current_status["progress"],
            "start_time": datetime.now().isoformat()
        })
        
        def update_progress(current_index: int, failed_count: int, total: int, current_file: str):
            current_status["progress"]["processed"] = current_index
            current_status["progress"]["failed"] = failed_count
            
            update_db_status({
                "progress": current_status["progress"],
                "current_file": current_file,
                "current_index": current_index,
                "message": f"Processing: {current_file}"
            })
            logger.info(f"Progress: {current_index}/{total} (Failed: {failed_count}) - {current_file}")
        
        from services.inventory_processor import process_inventory_batch

        results = process_inventory_batch(
            file_keys=r2_file_keys,
            r2_bucket=r2_bucket,
            username=username,
            progress_callback=update_progress,
            force_upload=force_upload
        )

        logger.info(f"Processing completed. Results: {results}")

        skipped_count = results.get("skipped_count", 0)
        skipped_details = results.get("skipped_duplicates", [])

        # Build compact skipped summary list for mobile display:
        # [{ file_key, invoice_number, invoice_date, receipt_link, message }]
        skipped_summary = []
        for dup in skipped_details:
            rec = dup.get("existing_record", {})
            skipped_summary.append({
                "file_key": dup.get("file_key", ""),
                "invoice_number": rec.get("invoice_number", ""),
                "invoice_date": rec.get("invoice_date", ""),
                "receipt_link": _resolve_receipt_link(rec.get("receipt_link", "")),
                "message": dup.get("message", "Already uploaded previously"),
            })

        update_db_status({
            "status": "completed",
            "progress": {
                "total": results.get("total", len(r2_file_keys)),
                "processed": results["processed"],
                "failed": results["failed"],
                "skipped": skipped_count,
                "skipped_details": skipped_summary,
                "errors": results.get("errors", []),
            },
            "message": _build_completion_message(results["processed"], skipped_count, results["failed"]),
            "current_file": "All complete",
            "duplicates": [],
            "end_time": datetime.now().isoformat()
        })
            
        # AUTO-RECALCULATION: Trigger stock recalculation after successful inventory processing
        # Advisory locks prevent race conditions with concurrent recalculations
        # if results["processed"] > 0:
        #     logger.info(f"🔄 Auto-triggering stock recalculation for {username}...")
        #     try:
        #         from routes.stock_routes import recalculate_stock_wrapper
        # 
        #         recalc_task_id = str(uuid.uuid4())
        # 
        #         try:
        #             from database import get_database_client
        #             db = get_database_client()
        #             db.insert("recalculation_tasks", {
        #                 "task_id": recalc_task_id,
        #                 "username": username,
        #                 "status": "queued",
        #                 "message": "Auto-triggered after inventory upload",
        #                 "progress": {"total": 0, "processed": 0},
        #                 "created_at": datetime.utcnow().isoformat()
        #             })
        #         except Exception as db_err:
        #             logger.warning(f"Could not create recalculation task record: {db_err}")
        # 
        #         recalculate_stock_wrapper(recalc_task_id, username)
        #         logger.info(f"✅ Stock recalculation queued for {username} (Task: {recalc_task_id})")
        #     except Exception as e:
        #         logger.error(f"❌ Auto-recalculation failed for {username}: {e}")

        if results.get("errors"):
            logger.warning(f"Processing errors: {results['errors']}")
        
    except Exception as e:
        logger.error("=== INVENTORY PROCESSING FAILED ===")
        logger.error(f"Error processing inventory: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        update_db_status({
            "status": "failed",
            "message": f"Processing failed: {str(e)}",
            "end_time": datetime.now().isoformat()
        })
    
    finally:
        logger.info("=== INVENTORY PROCESSING COMPLETED ===")


@router.get("/tracked-items")
async def get_tracked_items(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Returns verified inventory items grouped by description (item-level).
    Used by the mobile Track Items page. Each unique item description appears
    once, showing the latest price and order count.
    """
    from database import get_database_client

    username = current_user.get("username")
    db = get_database_client()

    try:
        response = db.client.table("inventory_items") \
            .select("*") \
            .eq("username", username) \
            .eq("verification_status", "Done") \
            .order("invoice_date", desc=True) \
            .execute()

        # Group by description to get unique items with latest price and order count
        description_map: Dict[str, Any] = {}  # key -> most recent row
        count_map: Dict[str, int] = {}

        for row in (response.data or []):
            desc = (row.get("description") or "").strip()
            if not desc:
                continue

            key = desc.lower()
            count_map[key] = count_map.get(key, 0) + 1

            if key not in description_map:
                description_map[key] = row
            else:
                # Keep most recent by invoice_date, then created_at as tiebreaker
                existing = description_map[key]
                existing_date = existing.get("invoice_date") or ""
                new_date = row.get("invoice_date") or ""
                if new_date > existing_date:
                    description_map[key] = row
                elif new_date == existing_date:
                    if (row.get("created_at") or "") > (existing.get("created_at") or ""):
                        description_map[key] = row

        items = []
        for key, row in description_map.items():
            items.append({
                "id": row.get("id"),
                "invoice_date": str(row.get("invoice_date") or ""),
                "invoice_number": row.get("invoice_number") or "",
                "vendor_name": row.get("vendor_name"),
                "part_number": row.get("part_number") or "",
                "description": row.get("description") or "",
                "quantity": float(row.get("quantity") or 1),
                "rate": float(row.get("rate") or 0),
                "net_bill": float(row.get("net_bill") or 0),
                "amount_mismatch": float(row.get("amount_mismatch") or row.get("mismatch_amount") or 0),
                "receipt_link": _resolve_receipt_link(row.get("receipt_link") or ""),
                "verification_status": "Done",
                "created_at": row.get("created_at"),
                "payment_mode": row.get("payment_mode"),
                "previous_rate": float(row.get("previous_rate") or 0) if row.get("previous_rate") else None,
                "price_hike_amount": float(row.get("price_hike_amount") or 0) if row.get("price_hike_amount") else None,
                "order_count": count_map.get(key, 1),
            })

        # Sort by most recently ordered
        items.sort(key=lambda x: x["invoice_date"], reverse=True)

        return {"success": True, "items": items, "count": len(items)}
    except Exception as e:
        logger.error(f"Error fetching tracked items: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/item-price-history")
async def get_item_price_history_by_description(
    description: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Returns the price history for a specific item by its description.
    Reads from inventory_items (verified items only), sorted chronologically ASC.
    Used by the price history bottom sheet in Track Items.
    """
    from database import get_database_client

    username = current_user.get("username")
    db = get_database_client()

    if not description:
        raise HTTPException(status_code=400, detail="Must provide description")

    try:
        response = db.client.table("inventory_items") \
            .select("*") \
            .eq("username", username) \
            .eq("verification_status", "Done") \
            .eq("description", description) \
            .order("invoice_date", desc=False) \
            .execute()

        items = []
        for row in (response.data or []):
            items.append({
                "id": row.get("id"),
                "invoice_date": str(row.get("invoice_date") or ""),
                "invoice_number": row.get("invoice_number") or "",
                "vendor_name": row.get("vendor_name"),
                "part_number": row.get("part_number") or "",
                "description": row.get("description") or "",
                "quantity": float(row.get("quantity") or 1),
                "rate": float(row.get("rate") or 0),
                "net_bill": float(row.get("net_bill") or 0),
                "amount_mismatch": float(row.get("amount_mismatch") or row.get("mismatch_amount") or 0),
                "receipt_link": _resolve_receipt_link(row.get("receipt_link") or ""),
                "verification_status": "Done",
                "created_at": row.get("created_at"),
                "payment_mode": row.get("payment_mode"),
                "previous_rate": float(row.get("previous_rate") or 0) if row.get("previous_rate") else None,
                "price_hike_amount": float(row.get("price_hike_amount") or 0) if row.get("price_hike_amount") else None,
            })

        return {"success": True, "items": items, "count": len(items)}
    except Exception as e:
        logger.error(f"Error fetching item price history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/vendor-price-history")
async def get_vendor_price_history(
    vendor_name: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Legacy: Returns invoice-level history for a vendor (kept for backward compat).
    """
    from database import get_database_client

    username = current_user.get("username")
    db = get_database_client()

    if not vendor_name:
        raise HTTPException(status_code=400, detail="Must provide vendor_name")

    try:
        response = db.client.table("inventory_invoices") \
            .select("*") \
            .eq("username", username) \
            .ilike("vendor_name", vendor_name) \
            .order("invoice_date", desc=False) \
            .execute()

        items = []
        for inv in (response.data or []):
            total = float(inv.get("total_amount") or 0)
            items.append({
                "id": inv.get("id"),
                "invoice_date": str(inv.get("invoice_date") or ""),
                "invoice_number": inv.get("invoice_number") or "",
                "vendor_name": inv.get("vendor_name"),
                "part_number": "",
                "description": inv.get("vendor_name") or "",
                "quantity": 1.0,
                "rate": total,
                "net_bill": total,
                "amount_mismatch": 0.0,
                "receipt_link": _resolve_receipt_link(inv.get("receipt_link") or ""),
                "verification_status": "Done",
                "created_at": inv.get("created_at"),
                "payment_mode": inv.get("payment_mode"),
            })

        return {"success": True, "items": items, "count": len(items)}
    except Exception as e:
        logger.error(f"Error fetching vendor price history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/items")
async def get_inventory_items(
    show_all: bool = False,
    invoice_number: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get inventory items with optional filtering.
    Default (show_all=False): Only show PENDING items (verification_status != 'Done')
    With show_all=True: Show all items including verified ones
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    try:
        # Base query
        query = db.client.table("inventory_items").select("*").eq("username", username)
        
        # CRITICAL: Apply filtering for reviews - exclude verified items
        if not show_all:
            # Only show items that are NOT verified (pending review)
            query = query.neq("verification_status", "Done")
        
        # Apply invoice_number filter if provided
        if invoice_number:
            query = query.eq("invoice_number", invoice_number)
        
        # Order by created_at descending
        query = query.order("created_at", desc=True)
        
        response = query.execute()
        
        # Resolve r2:// URLs in response
        items = response.data or []
        for item in items:
            if item.get("receipt_link", "").startswith("r2://"):
                item["receipt_link"] = _resolve_receipt_link(item["receipt_link"])

        return {
            "success": True,
            "items": items,
            "count": len(items)
        }
    except Exception as e:
        logger.error(f"Error fetching inventory items: {e}")
        raise HTTPException(status_code=500, detail=str(e))
@router.get("/items/price-history")
async def get_item_price_history(
    description: Optional[str] = None,
    part_number: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get the price history of a specific inventory item by its description or part number.
    Only includes verified items (verification_status = 'Done'), chronologically sorted.
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    # Log the request for debugging
    logger.info(f"Fetching price history for item: description='{description}', part_number='{part_number}' (user: {username})")
    
    try:
        # Base query for this user's verified items
        query = db.client.table("inventory_items").select("*") \
            .eq("username", username) \
            .eq("verification_status", "Done")
            
        if description:
            query = query.eq("description", description)
        elif part_number:
            query = query.eq("part_number", part_number)
        else:
            raise HTTPException(status_code=400, detail="Must provide description or part_number")
            
        # Order chronologically for the sparkline chart
        query = query.order("invoice_date", desc=False).order("created_at", desc=False)
        
        response = query.execute()
        
        # Resolve r2:// URLs
        items = response.data or []
        for item in items:
            if item.get("receipt_link", "").startswith("r2://"):
                item["receipt_link"] = _resolve_receipt_link(item["receipt_link"])

        return {
            "success": True,
            "items": items,
            "count": len(items)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching item price history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/verify-invoice")
async def verify_inventory_invoice(
    request: InventoryInvoiceVerifyRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Verify an inventory invoice, creating an inventory_invoices parent record
    and updating the matched inventory_items.
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    try:
        if not request.item_ids:
            raise HTTPException(status_code=400, detail="No items provided to verify")
            
        # 1. Fetch items to get total amount and receipt link
        item_response = db.client.table("inventory_items") \
            .select("id, net_bill, receipt_link, image_hash, inventory_invoice_id, verification_status") \
            .in_("id", request.item_ids) \
            .eq("username", username) \
            .execute()
            
        if not item_response.data:
            raise HTTPException(status_code=404, detail="No valid items found")
            
        sum_net_bill = sum(float(item.get("net_bill", 0)) for item in item_response.data)
        receipt_link = item_response.data[0].get("receipt_link", "")
        image_hash = item_response.data[0].get("image_hash", "")

        # Check if an existing invoice already links these items
        existing_invoice_id = None
        for item in item_response.data:
            if item.get("inventory_invoice_id"):
                existing_invoice_id = item.get("inventory_invoice_id")
                break

        if request.final_total is not None:
            total_amount = request.final_total
        elif request.adjustments is not None:
            adj_sum = sum(float(adj.get("amount", 0)) for adj in request.adjustments)
            total_amount = sum_net_bill + adj_sum
        else:
            total_amount = sum_net_bill

        # 2. Upsert into inventory_invoices
        invoice_data = {
            "username": username,
            "invoice_number": request.invoice_number,
            "vendor_name": request.vendor_name,
            "invoice_date": request.invoice_date,
            "receipt_link": receipt_link,
            "total_amount": total_amount,
            "payment_mode": request.payment_mode,
            "payment_date": request.payment_date,
            "amount_paid": request.amount_paid,
            "balance_owed": request.balance_owed,
            "vendor_notes": request.vendor_notes,
            "car_number": request.car_number,
            "vehicle_number": request.vehicle_number,
            "extra_fields": request.extra_fields or {}
        }
        
        from datetime import datetime
        if existing_invoice_id:
            # Fetch old invoice to rollback vendor ledger if necessary
            inv_resp = db.client.table("inventory_invoices").select("*").eq("id", existing_invoice_id).execute()
            existing_invoice = inv_resp.data[0] if inv_resp.data else None

            db.client.table("inventory_invoices").update(invoice_data).eq("id", existing_invoice_id).execute()
            new_invoice_id = existing_invoice_id

            if existing_invoice:
                old_balance = float(existing_invoice.get("balance_owed") or 0.0)
                old_vendor = str(existing_invoice.get("vendor_name") or "").strip()
                
                # Reverse old_balance from old vendor's ledger
                if old_balance > 0 and old_vendor:
                    # Fetch the transaction to properly handle its state (e.g. linked payments)
                    tx_resp = db.client.table("vendor_ledger_transactions").select("*").eq("invoice_number", existing_invoice.get("invoice_number")).eq("transaction_type", "INVOICE").eq("username", username).execute()
                    if tx_resp.data:
                        tx = tx_resp.data[0]
                        tx_id = tx["id"]
                        is_paid = tx.get("is_paid", False)
                        old_ld_id = tx.get("ledger_id")
                        
                        # If paid, delete the linked auto-payment transaction first to avoid leaving orphaned payments
                        if is_paid:
                            db.client.table("vendor_ledger_transactions").delete().eq("linked_transaction_id", tx_id).eq("username", username).execute()
                        
                        old_ld_resp = db.client.table("vendor_ledgers").select("*").eq("id", old_ld_id).execute()
                        if old_ld_resp.data:
                            old_ld = old_ld_resp.data[0]
                            # Net change to balance: If INVOICE was unpaid, it contributed +amount. So we subtract it.
                            # If INVOICE was paid, it contributed +amount and the PAYMENT contributed -amount (Net = 0). So we don't subtract.
                            if not is_paid:
                                new_old_balance = float(old_ld.get("balance_due", 0)) - float(tx.get("amount", 0))
                                db.client.table("vendor_ledgers").update({
                                    "balance_due": new_old_balance,
                                    "updated_at": datetime.utcnow().isoformat()
                                }).eq("id", old_ld_id).execute()
                        
                        # Finally, delete the old INVOICE transaction completely
                        db.client.table("vendor_ledger_transactions").delete().eq("id", tx_id).execute()
        else:
            invoice_response = db.client.table("inventory_invoices").insert(invoice_data).execute()
            if not invoice_response.data:
                raise HTTPException(status_code=500, detail="Failed to save invoice details")
            new_invoice_id = invoice_response.data[0]["id"]
            
            # Log usage for the new supplier order
            try:
                # Use a deterministic UUID to prevent double-counting if this invoice is re-processed
                log_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"supplier-{username}-{new_invoice_id}"))
                db.client.table('usage_logs').upsert([{
                    "id": log_id,
                    "username": username,
                    "order_type": "supplier"
                }]).execute()
                logger.info(f"Logged new supplier order to usage metrics")
            except Exception as e:
                logger.error(f"Failed to log supplier usage metrics: {e}")

        # 3. Update all linked inventory_items to Verification Status = 'Done' and link invoice ID
        update_data = {
            "verification_status": "Done",
            "inventory_invoice_id": new_invoice_id
        }
        
        db.client.table("inventory_items") \
            .update(update_data) \
            .in_("id", request.item_ids) \
            .eq("username", username) \
            .execute()
            
        # 3.5 Handle Header Adjustments
        db.client.table("invoice_adjustments") \
            .delete() \
            .eq("invoice_number", request.invoice_number) \
            .eq("username", username) \
            .execute()
            
        if request.adjustments:
            adj_inserts = []
            for adj in request.adjustments:
                adj_inserts.append({
                    "username": username,
                    "invoice_number": request.invoice_number,
                    "invoice_date": request.invoice_date,
                    "image_hash": image_hash,
                    "adjustment_type": adj.get("adjustment_type") or adj.get("adjustmentType", "OTHER"),
                    "amount": float(adj.get("amount", 0)),
                    "description": adj.get("description")
                })
            if adj_inserts:
                db.client.table("invoice_adjustments").insert(adj_inserts).execute()
            
        # 4. Handle Vendor Ledger (Process all vendors to ensure they appear in the Parties list)
        if request.vendor_name:
            vendor_name_clean = str(request.vendor_name).strip()
            balance_owed_val = request.balance_owed if request.balance_owed is not None else 0.0
            balance_owed_float = float(balance_owed_val)
            
            # Fetch existing ledger (case-insensitive to prevent duplicate ledgers)
            ledger_resp = db.client.table('vendor_ledgers') \
                .select('*') \
                .eq('username', username) \
                .ilike('vendor_name', vendor_name_clean) \
                .execute()
                
            if ledger_resp.data:
                ledger = ledger_resp.data[0]
                new_balance = float(ledger.get('balance_due', 0)) + balance_owed_float
                db.client.table('vendor_ledgers').update({
                    'balance_due': new_balance,
                    'updated_at': datetime.utcnow().isoformat()
                }).eq('id', ledger['id']).execute()
                ledger_id = ledger['id']
            else:
                new_ledger_resp = db.client.table('vendor_ledgers').insert({
                    'username': username,
                    'vendor_name': vendor_name_clean,
                    'balance_due': balance_owed_float,
                }).execute()
                
                if new_ledger_resp.data:
                    ledger_id = new_ledger_resp.data[0]['id']
                else:
                    ledger_id = None
            
            if ledger_id:
                # Check if transaction already exists for this invoice number
                tx_exists = db.client.table('vendor_ledger_transactions') \
                    .select('id') \
                    .eq('username', username) \
                    .eq('ledger_id', ledger_id) \
                    .eq('invoice_number', request.invoice_number) \
                    .eq('transaction_type', 'INVOICE') \
                    .execute()
                
                if not tx_exists.data:
                    db.client.table('vendor_ledger_transactions').insert({
                        'username': username,
                        'ledger_id': ledger_id,
                        'transaction_type': 'INVOICE',
                        'amount': balance_owed_float,
                        'invoice_number': request.invoice_number,
                        'is_paid': (request.payment_mode != 'Credit' or balance_owed_float == 0),
                        'notes': request.vendor_notes,
                        'car_number': request.car_number,
                        'vehicle_number': request.vehicle_number,
                        'extra_fields': request.extra_fields or {}
                    }).execute()
            
        return {
            "success": True,
            "message": "Invoice verified and saved successfully",
            "invoice_id": new_invoice_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error verifying inventory invoice: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/items/{item_id}")
async def update_inventory_item(
    item_id: int,
    updates: Dict[str, Any],
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Update an inventory item
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    try:
        # Add updated_at timestamp
        updates["updated_at"] = datetime.now().isoformat()
        
        # Update the item
        response = db.client.table("inventory_items")\
            .update(updates)\
            .eq("id", item_id)\
            .eq("username", username)\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Item not found")
        
        return {
            "success": True,
            "item": response.data[0]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating inventory item: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/items/{item_id}")
async def delete_inventory_item(
    item_id: int,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Delete an inventory item by ID
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    try:
        # Delete the item
        response = db.client.table("inventory_items")\
            .delete()\
            .eq("id", item_id)\
            .eq("username", username)\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Item not found")
        
        logger.info(f"Deleted inventory item with id: {item_id}")
        
        return {
            "success": True,
            "message": f"Deleted inventory item {item_id}"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting inventory item: {e}")
        raise HTTPException(status_code=500, detail=str(e))



@router.delete("/by-hash/{image_hash}")
async def delete_by_image_hash(
    image_hash: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Delete all inventory items with the given image_hash (for duplicate replacement)
    """
    from database import get_database_client
    
    try:
        db = get_database_client()
        username = current_user.get("username")
        
        # Delete all items with this image_hash for this user
        result = db.client.table("inventory_items")\
            .delete()\
            .eq("image_hash", image_hash)\
            .eq("username", username)\
            .execute()
        
        deleted_count = len(result.data) if result.data else 0
        
        logger.info(f"Deleted {deleted_count} inventory items with image_hash: {image_hash}")
        
        return {
            "success": True,
            "deleted_count": deleted_count,
            "message": f"Deleted {deleted_count} inventory item(s)"
        }
        
    except Exception as e:
        logger.error(f"Error deleting inventory items by image_hash: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/delete-bulk")
async def delete_bulk_inventory_items(
    request: Dict[str, Any],
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Delete multiple inventory items by IDs
    """
    from database import get_database_client
    
    username = current_user.get("username")
    
    if not username:
        raise HTTPException(status_code=400, detail="No username in token")
    
    ids = request.get('ids', [])
    if not ids:
        raise HTTPException(status_code=400, detail="ids array is required")
    
    if not isinstance(ids, list):
        raise HTTPException(status_code=400, detail="ids must be an array")
    
    try:
        db = get_database_client()
        
        # Bulk delete all items in a single query instead of N sequential deletes
        response = db.client.table("inventory_items")\
            .delete()\
            .in_("id", ids)\
            .eq("username", username)\
            .execute()
        
        deleted_count = len(response.data) if response.data else 0
        
        logger.info(f"Deleted {deleted_count} inventory items for {username}")
        
        return {
            "success": True,
            "message": f"Deleted {deleted_count} items successfully",
            "deleted_count": deleted_count
        }
    
    except Exception as e:
        logger.error(f"Error deleting inventory items in bulk: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete inventory items: {str(e)}")


@router.get("/export")
async def export_inventory_to_excel(
    search: Optional[str] = None,
    invoice_number: Optional[str] = None,
    part_number: Optional[str] = None,
    description: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    status: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Export filtered inventory items to Excel
    Includes ALL columns up to amount_mismatch from the database
    """
    from database import get_database_client
    
    username = current_user.get("username")
    db = get_database_client()
    
    try:
        # Build query with all columns
        query = db.client.table("inventory_items").select("*").eq("username", username)
        
        # Apply filters
        if invoice_number:
            query = query.ilike("invoice_number", f"%{invoice_number}%")
        
        if part_number:
            query = query.ilike("part_number", f"%{part_number}%")
        
        if description:
            query = query.ilike("description", f"%{description}%")
        
        if date_from:
            query = query.gte("invoice_date", date_from)
        
        if date_to:
            query = query.lte("invoice_date", date_to)
        
        # Order by upload_date descending
        query = query.order("upload_date", desc=True)
        
        response = query.execute()
        items = response.data or []
        
        # Apply status filter (post-query since it's computed)
        if status:
            items = [
                item for item in items
                if (item.get('amount_mismatch', 0) == 0 and status == 'Done') or
                   (item.get('amount_mismatch', 0) != 0 and item.get('verification_status', 'Pending') == status)
            ]
        
        # Apply general search filter (post-query)
        if search:
            search_lower = search.lower()
            items = [
                item for item in items
                if any(str(val).lower().find(search_lower) != -1 for val in item.values() if val is not None)
            ]
        
        if not items:
            # Return empty Excel file
            df = pd.DataFrame()
        else:
            # Select columns up to and including amount_mismatch
            columns_to_export = [
                'id',
                'invoice_date',
                'invoice_number',
                'part_number',
                'batch',
                'description',
                'hsn',
                'quantity',
                'rate',
                'disc_percent',
                'taxable_amount',
                'cgst_percent',
                'sgst_percent',
                'discounted_price',
                'taxed_amount',
                'net_bill',
                'amount_mismatch',
                'verification_status',
                'upload_date',
                'receipt_link',
            ]
            
            # Filter to only existing columns
            available_columns = [col for col in columns_to_export if col in items[0]]
            
            # Create DataFrame
            df = pd.DataFrame(items)[available_columns]
            
            # Rename columns for better readability
            column_names = {
                'id': 'ID',
                'invoice_date': 'Invoice Date',
                'invoice_number': 'Invoice Number',
                'part_number': 'Part Number',
                'batch': 'Batch',
                'description': 'Description',
                'hsn': 'HSN',
                'quantity': 'Quantity',
                'rate': 'Rate',
                'disc_percent': 'Discount %',
                'taxable_amount': 'Taxable Amount',
                'cgst_percent': 'CGST %',
                'sgst_percent': 'SGST %',
                'discounted_price': 'Discounted Price',
                'taxed_amount': 'Taxed Amount',
                'net_bill': 'Net Bill',
                'amount_mismatch': 'Amount Mismatch',
                'verification_status': 'Verification Status',
                'upload_date': 'Upload Date',
                'receipt_link': 'Receipt Link',
            }
            df.rename(columns=column_names, inplace=True)
        
        # Create Excel file in memory
        output = BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, index=False, sheet_name='Inventory')
            
            # Auto-adjust column widths
            worksheet = writer.sheets['Inventory']
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)
                worksheet.column_dimensions[column_letter].width = adjusted_width
        
                # Add this code after line 583 in inventory.py (after worksheet.column_dimensions[column_letter].width = adjusted_width)
                hyperlink_code = """
                            # Convert receipt links to clickable hyperlinks
                            from openpyxl.styles import Font, colors
                            receipt_link_col = None
                            for idx, col in enumerate(worksheet[1], 1):  # Header row
                                if col.value == 'Receipt Link':
                                    receipt_link_col = idx
                                    break
                            
                            if receipt_link_col:
                                for row_idx in range(2, worksheet.max_row + 1):  # Skip header
                                    cell = worksheet.cell(row=row_idx, column=receipt_link_col)
                                    if cell.value and str(cell.value).startswith('http'):
                                        cell.hyperlink = cell.value
                                        cell.value = 'View Image'
                                        cell.font = Font(color=colors.BLUE, underline='single')
                """
        output.seek(0)
        
        # Return as streaming response
        filename = f"inventory_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        
        return StreamingResponse(
            output,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
        
    except Exception as e:
        logger.error(f"Error exporting inventory to Excel: {e}")
        raise HTTPException(status_code=500, detail=str(e))
