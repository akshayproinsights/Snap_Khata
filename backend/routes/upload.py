"""Upload and processing routes"""
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, BackgroundTasks
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime
import uuid
import asyncio
import os
from concurrent.futures import ThreadPoolExecutor

from auth import get_current_user, get_current_user_r2_bucket
from services.storage import get_storage_client
from utils.image_optimizer import optimize_image_for_gemini, should_optimize_image, validate_image_quality
from config import get_sales_folder, get_purchases_folder
from database import get_database_client, create_fresh_database_client

router = APIRouter()
logger = logging.getLogger(__name__)

# Thread pool for blocking operations (Optimized for high-load: 50 concurrent tasks)
# Configurable via environment variable
executor = ThreadPoolExecutor(max_workers=int(os.getenv('UPLOAD_MAX_WORKERS', '50')))

# In-memory storage REMOVED - using database table 'upload_tasks'
# processing_status: Dict[str, Dict[str, Any]] = {}


class UploadResponse(BaseModel):
    """Upload response model"""
    success: bool
    uploaded_files: List[str]
    message: str


class ProcessRequest(BaseModel):
    """Process invoices request model"""
    file_keys: List[str]
    force_upload: bool = True  # If True, bypass duplicate checking and delete old duplicates


class ProcessResponse(BaseModel):
    """Process invoices response model"""
    task_id: str
    status: str
    message: str
    duplicates: List[Dict[str, Any]] = []  # List of duplicate information


class ProcessStatusResponse(BaseModel):
    """Process status response model"""
    task_id: str
    status: str
    progress: Dict[str, Any]
    message: str
    duplicates: List[Dict[str, Any]] = []  # Add duplicates field
    uploaded_r2_keys: List[str] = []  # CRITICAL: R2 keys for frontend

class UploadHistoryItem(BaseModel):
    date: str
    count: int
    receipt_ids: List[str]

class UploadHistorySummary(BaseModel):
    last_active_date: Optional[str] = None
    last_receipt_number: Optional[str] = None
    status: str = "caught_up"

class UploadHistoryResponse(BaseModel):
    summary: UploadHistorySummary
    history: List[UploadHistoryItem]

@router.get("/upload-history", response_model=UploadHistoryResponse)
def get_upload_history(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get upload history and status for the "Resume" banner.
    Returns:
    - Last active date and receipt number
    - Recent history grouped by date (last 10 entries)
    """
    try:
        username = current_user['username']
        db = get_database_client()
        supabase = db.client
        
        # 1. Fetch recent invoices for history (limit 100 to process in memory)
        # ORDER BY date (receipt date) DESC to get most recent receipts by invoice date
        # This is what SMB users care about - "what's my latest receipt?" not "when did I upload?"
        response = supabase.table('invoices') \
            .select('date, receipt_number, created_at') \
            .eq('username', username) \
            .order('date', desc=True) \
            .limit(100) \
            .execute()
            
        invoices = response.data if response.data else []
        
        if not invoices:
            return {
                "summary": {
                    "last_active_date": None,
                    "last_receipt_number": None,
                    "status": "no_uploads"
                },
                "history": []
            }
            
        # 2. Process for Summary (Latest Upload)
        # CRITICAL: Use receipt date (date field) - this is what SMB users care about
        # "What's my latest receipt by date?" not "when did I upload?"
        # ALSO: Within the same date, pick the receipt with the HIGHEST receipt number
        latest_receipt_date = invoices[0].get('date', '')  # Latest date
        
        # Find all receipts for this date and pick the one with max receipt_number
        receipts_on_latest_date = [inv for inv in invoices if inv.get('date') == latest_receipt_date]
        latest_invoice = max(receipts_on_latest_date, key=lambda x: int(x.get('receipt_number', 0) or 0))
        
        
        # 3. Process for History (Group by Date)
        # Group by the 'date' field (invoice date)
        history_map = {}
        
        for inv in invoices:
            date_str = inv.get('date') or 'Unknown Date'
            receipt_num = inv.get('receipt_number') or 'N/A'
            
            if date_str not in history_map:
                history_map[date_str] = {
                    "date": date_str,
                    "count": 0,
                    "receipt_ids": [],
                    "seen_receipts": set()  # Track unique receipts
                }
            
            # Only increment count once per unique receipt number
            if receipt_num not in history_map[date_str]["seen_receipts"]:
                history_map[date_str]["count"] += 1
                history_map[date_str]["seen_receipts"].add(receipt_num)
                
                # Only show first 10 unique receipts per day in the chip list
                if len(history_map[date_str]["receipt_ids"]) < 10:
                    history_map[date_str]["receipt_ids"].append(f"#{receipt_num}")
                
        # Convert map to list and sort by date descending
        history_list = sorted(
            history_map.values(), 
            key=lambda x: x['date'], 
            reverse=True
        )
        
        # formatting history items (remove seen_receipts set before returning)
        final_history = []
        for item in history_list:
             # Sort receipt_ids in ascending numerical order
             if item.get('receipt_ids'):
                 # Extract numbers from "#123" format and sort
                 item['receipt_ids'] = sorted(
                     item['receipt_ids'],
                     key=lambda x: int(x.replace('#', '')) if x.replace('#', '').isdigit() else 0
                 )
             # Remove the tracking set before creating the response model
             item.pop('seen_receipts', None)
             final_history.append(UploadHistoryItem(**item))
             
        return {
            "summary": {
                "last_active_date": latest_receipt_date,  # Use receipt date - what SMB users care about
                "last_receipt_number": latest_invoice.get('receipt_number'),
                "status": "caught_up"
            },
            "history": final_history[:7] # Return last 7 active revenue dates
        }
        
    except Exception as e:
        print(f"Error fetching upload history: {e}")
        # Return empty structure on error to avoid breaking UI
        return {
            "summary": {"status": "error"},
            "history": []
        }



@router.post("/files", response_model=UploadResponse)
async def upload_files(
    files: List[UploadFile] = File(...),
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    Upload sales invoice files to R2 storage CONCURRENTLY.
    All files are uploaded to R2 in parallel (asyncio.gather),
    reducing upload time from N×T to ~T for a batch of N files.
    """
    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded")
    
    username = current_user.get("username", "user")
    logger.info(f"Received {len(files)} sales files for upload from {username}")
    
    try:
        # Read all file bytes into memory first (async, fast)
        file_data_list = []
        for file in files:
            content = await file.read()
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            unique_id = uuid.uuid4().hex[:6]
            sales_folder = get_sales_folder(username)
            # Ensure file has an extension, default to .jpg since our optimizer always outputs JPEG
            filename = file.filename or ""
            if not filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                filename = f"{filename}.jpg"
            
            file_key = f"{sales_folder}{timestamp}_{unique_id}_{filename}"
            file_data_list.append({
                'content': content,
                'filename': filename,
                'file_key': file_key
            })
        
        logger.info(f"Starting PARALLEL upload of {len(file_data_list)} sales files for {username}")
        
        # Upload all files in parallel — each runs in the thread pool
        # Semaphore caps concurrency at 10 to avoid R2 overload
        semaphore = asyncio.Semaphore(10)
        loop = asyncio.get_event_loop()

        async def upload_one(file_data: Dict[str, Any]) -> Optional[str]:
            async with semaphore:
                return await loop.run_in_executor(
                    executor,
                    upload_single_file_sync,
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

        logger.info(f"Successfully uploaded {len(uploaded_keys)}/{len(file_data_list)} files in parallel")
        
        return {
            "success": True,
            "uploaded_files": uploaded_keys,
            "message": f"Successfully uploaded {len(uploaded_keys)} file(s)"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in upload_files: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


# process_uploads_batch_sync is no longer used — upload_files now uses
# asyncio.gather() for parallel uploads. Kept as a no-op stub for safety.
def process_uploads_batch_sync(
    file_data_list: List[Dict[str, Any]],
    username: str,
    r2_bucket: str
) -> List[str]:
    """Deprecated: parallel upload is now done directly in upload_files endpoint."""
    logger.warning("process_uploads_batch_sync called — this is deprecated. Use parallel upload_files instead.")
    return []


def upload_single_file_sync(
    content: bytes,
    filename: str,
    username: str,
    r2_bucket: str,
    file_key: str  # NEW: Accept pre-generated key
) -> Optional[str]:
    """
    Synchronous helper for single file upload - runs in background task.
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
        
        # Optimize image before upload (if needed)
        if should_optimize_image(content):
            logger.info(f"Optimizing image: {filename}")
            optimized_content, metadata = optimize_image_for_gemini(content)
            
            logger.info(f"Optimization results for {filename}:")
            logger.info(f"  Original: {metadata['original_size_kb']}KB, {metadata['original_dimensions'][0]}x{metadata['original_dimensions'][1]}")
            logger.info(f"  Optimized: {metadata['optimized_size_kb']}KB, {metadata['final_dimensions'][0]}x{metadata['final_dimensions'][1]}")
            logger.info(f"  Compression: {metadata['compression_ratio']}% reduction")
            
            content = optimized_content
        else:
            logger.info(f"Skipping optimization for {filename} (already optimal)")
        
        # Determine content type (always JPEG after optimization)
        content_type = "image/jpeg"  # Our optimizer always outputs JPEG
        
        # Upload to R2 using pre-generated key
        success = storage.upload_file(
            file_data=content,
            bucket=r2_bucket,
            key=file_key,
            content_type=content_type
        )
        
        if success:
            logger.info(f"Uploaded file: {file_key}")
            return file_key
        else:
            logger.error(f"Failed to upload file: {filename}")
            return None
            
    except Exception as e:
        logger.error(f"Error in upload_single_file_sync for {filename}: {e}")
        return None


class InternalProcessRequest(BaseModel):
    task_id: str
    file_keys: List[str]
    r2_bucket: str
    username: str
    force_upload: bool = False

    class Config:
        # Accept and ignore extra fields (e.g. old payloads with sheet_id)
        extra = "ignore"

@router.post("/internal/process-task")
async def internal_process_task(request: InternalProcessRequest):
    """
    Internal Webhook for Google Cloud Tasks.
    Since Cloud Tasks manages retries/timeouts and keeps the HTTP connection open,
    this runs SYNCHRONOUSLY to prevent Cloud Run CPU from throttling to zero.
    Requires OIDC authentication verified by Cloud Run automatically.
    """
    try:
        logger.info(f"[CLOUD-TASK-WEBHOOK] Received request for task {request.task_id}")
        logger.info(f"[CLOUD-TASK-WEBHOOK] task_id={request.task_id}, username={request.username}, "
                    f"file_keys_count={len(request.file_keys)}, r2_bucket={request.r2_bucket}, "
                    f"force_upload={request.force_upload}")
        # Run synchronously on the main thread
        process_invoices_sync(
            task_id=request.task_id,
            file_keys=request.file_keys,
            r2_bucket=request.r2_bucket,
            username=request.username,
            force_upload=request.force_upload
        )
        logger.info(f"[CLOUD-TASK-WEBHOOK] Task {request.task_id} processed successfully")
        return {"status": "success", "message": f"Task {request.task_id} processed"}
    except Exception as e:
        logger.error(f"[CLOUD-TASK-WEBHOOK] Processing FAILED for task {request.task_id}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/process-files")  # RENAMED from /process to work around routing issue
async def process_invoices_endpoint(
    request: ProcessRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    Trigger invoice processing in thread pool (for blocking I/O operations)
    """
    task_id = str(uuid.uuid4())
    username = current_user.get("username", "user")
    
    logger.info(f"========== PROCESS FILES ENDPOINT CALLED ==========")
    logger.info(f"User: {username}")
    logger.info(f"Task ID: {task_id}")
    logger.info(f"Number of files to process: {len(request.file_keys)}")
    logger.info(f"File keys: {request.file_keys}")
    logger.info(f"Force upload: {request.force_upload}")
    logger.info(f"R2 Bucket: {r2_bucket}")

    # ── REQUEST-LEVEL IDEMPOTENCY GUARD ──────────────────────────────────────
    # Prevent the same R2 file keys from being submitted while a task is still
    # active (queued / processing). This closes the race window where two rapid
    # calls (e.g. from a polling retry) could both pass the image-hash DB check
    # before either has written results, causing Gemini to run twice.
    #
    # Strategy: query the last 10 active tasks for this user and check whether
    # any of them contain an overlapping set of uploaded_r2_keys.
    # We deliberately skip this guard when force_upload=True (user explicitly
    # wants to reprocess).
    if not request.force_upload:
        try:
            _guard_db = get_database_client()
            _active_tasks = _guard_db.client.table("upload_tasks") \
                .select("task_id, status, uploaded_r2_keys, created_at") \
                .eq("username", username) \
                .eq("task_type", "sales") \
                .in_("status", ["queued", "processing", "uploading"]) \
                .order("created_at", desc=True) \
                .limit(10) \
                .execute()

            incoming_keys = set(request.file_keys)
            for active_task in (_active_tasks.data or []):
                existing_keys = set(active_task.get("uploaded_r2_keys") or [])
                overlap = incoming_keys & existing_keys
                if overlap:
                    existing_task_id = active_task.get("task_id")
                    logger.warning(
                        f"[IDEMPOTENCY GUARD] Duplicate submission blocked for {username}. "
                        f"Overlapping keys: {overlap}. "
                        f"Existing active task: {existing_task_id}"
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
            raise  # Re-raise 409 as-is
        except Exception as guard_err:
            # Non-fatal: if the guard check fails, log and continue rather than
            # blocking a legitimate upload.
            logger.warning(f"[IDEMPOTENCY GUARD] Check failed (non-fatal), proceeding: {guard_err}")
    # ── END IDEMPOTENCY GUARD ─────────────────────────────────────────────────

    # ── FILE PATH VALIDATION ──────────────────────────────────────────────────
    # CRITICAL: Ensure all files are from the sales/ folder, not inventory/ folder
    # This prevents accidental routing of sales bills to supplier purchases
    expected_prefix = get_sales_folder(username)  # e.g., "akshaykh/sales/"
    inventory_prefix = get_purchases_folder(username)  # e.g., "akshaykh/inventory/"
    
    invalid_files = []
    for file_key in request.file_keys:
        if not file_key.startswith(expected_prefix):
            invalid_files.append(file_key)
            # Log warning if file is in inventory folder
            if file_key.startswith(inventory_prefix):
                logger.error(f"⚠️ ROUTING ERROR: File {file_key} is in INVENTORY folder but being processed as SALES. This indicates a frontend/mobile routing issue!")
    
    if invalid_files:
        logger.error(f"Rejecting sales process request: {len(invalid_files)}/{len(request.file_keys)} files are not from sales folder")
        logger.error(f"Expected prefix: {expected_prefix}")
        logger.error(f"Invalid files: {invalid_files}")
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file paths for sales processing. Expected files from '{expected_prefix}' folder. "
                   f"Please check that you used the 'Sales' upload, not 'Supplier/Inventory' upload. "
                   f"Invalid: {', '.join(invalid_files[:3])}"
        )
    # ── END FILE PATH VALIDATION ──────────────────────────────────────────────

    # Initialize status in DATABASE
    initial_status = {
        "task_id": task_id,
        "username": username,
        "status": "queued",
        "task_type": "sales",  # NEW: Distinguish task type
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
        db = get_database_client()
        db.insert("upload_tasks", initial_status)
        logger.info(f"Created task {task_id} for user {username} in database")
    except Exception as e:
        logger.error(f"Failed to create task in DB: {e}")
        # convert to HTTP 500
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    # Run in thread pool for blocking I/O operations
    try:
        # FILE LOGGING with UTF-8 encoding (fixes Windows Unicode errors)
        with open("process_debug.log", "a", encoding="utf-8") as f:
            f.write(f"\n{'='*80}\n")
            f.write(f"{datetime.now()}: RECEIVED PROCESS REQUEST\n")
            f.write(f"Task ID: {task_id}\n")
            f.write(f"Files: {request.file_keys}\n")
            f.write(f"Force upload: {request.force_upload}\n")
            f.write(f"{'='*80}\n\n")
        
        logger.info(f"Submitting task {task_id} to executor...")
        
        use_cloud_tasks = os.getenv('USE_CLOUD_TASKS', 'False').lower() == 'true'
        
        if use_cloud_tasks:
            try:
                from services.cloud_tasks import enqueue_process_invoices_task
                success = enqueue_process_invoices_task(
                    task_id=task_id,
                    file_keys=request.file_keys,
                    r2_bucket=r2_bucket,
                    username=username,
                    force_upload=request.force_upload
                )
                if success:
                    logger.info(f"Task {task_id} submitted to Cloud Tasks successfully")
                else:
                    raise Exception("Cloud Tasks submission returned False")
            except ImportError:
                logger.error("google-cloud-tasks not installed. Falling back to local thread pool.")
                use_cloud_tasks = False
            except Exception as e:
                logger.error(f"Cloud Tasks failed: {e}. Falling back to local thread pool.")
                use_cloud_tasks = False
                
        if not use_cloud_tasks:
            # Fallback to local ThreadPoolExecutor (for local development or if CT fails)
            loop = asyncio.get_event_loop()
            loop.run_in_executor(
                executor,
                process_invoices_sync,
                task_id,
                request.file_keys,
                r2_bucket,
                username,
                request.force_upload
            )
            logger.info(f"Task {task_id} submitted locally successfully")
    except Exception as e:
        logger.error(f"Failed to submit task {task_id}: {e}")
        # Try to update status to failed in DB
        try:
             db.update("upload_tasks", {"status": "failed", "message": f"Failed to start: {str(e)}"}, {"task_id": task_id})
        except:
             pass
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to start processing: {str(e)}")
    
    return {
        "task_id": task_id,
        "status": "queued",
        "message": f"Processing {len(request.file_keys)} file(s) in background",
        "duplicates": []  # Will be populated during processing
    }



@router.get("/process/status/{task_id}", response_model=ProcessStatusResponse)
async def get_process_status(
    task_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get processing status for a task from DATABASE
    """
    try:
        db = get_database_client()
        # Query task by ID
        response = db.query("upload_tasks").eq("task_id", task_id).execute()
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(status_code=404, detail="Task not found")
        
        status_record = response.data[0]
        
        # ── TIMEOUT SAFEGUARD ──────────────────────────────────────────
        # Auto-fail tasks stuck in processing/queued for >30 minutes
        # Prevents users from being stuck on the loading screen forever
        task_status = status_record.get("status", "unknown")
        if task_status in ("processing", "queued", "uploading"):
            created_at_str = status_record.get("created_at", "")
            if created_at_str:
                try:
                    created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
                    age_minutes = (datetime.now(created_at.tzinfo if created_at.tzinfo else None) - created_at).total_seconds() / 60
                    if age_minutes > 30:
                        logger.warning(f"Task {task_id} stuck for {age_minutes:.0f} min — auto-failing")
                        db.update("upload_tasks", {
                            "status": "failed",
                            "message": f"Task timed out after {age_minutes:.0f} minutes. Please try again.",
                            "updated_at": datetime.utcnow().isoformat()
                        }, {"task_id": task_id})
                        task_status = "failed"
                        status_record["status"] = "failed"
                        status_record["message"] = f"Task timed out after {age_minutes:.0f} minutes. Please try again."
                except Exception as timeout_err:
                    logger.warning(f"Could not check task timeout: {timeout_err}")
        # ── END TIMEOUT SAFEGUARD ──────────────────────────────────────

        return {
            "task_id": status_record.get("task_id"),
            "status": status_record.get("status", "unknown"),
            "progress": status_record.get("progress", {}),
            "message": status_record.get("message", ""),
            "duplicates": status_record.get("duplicates") or [],
            "uploaded_r2_keys": status_record.get("uploaded_r2_keys") or []
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching task status {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch status: {str(e)}")


@router.get("/recent-task", response_model=Optional[ProcessStatusResponse])
async def get_recent_sales_task(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get the most recent upload task for the current user.
    Useful for resuming progress bars if the user refreshes the page.
    Returns None if no task found (instead of 404 to avoid console errors).
    """
    try:
        db = get_database_client()
        
        # Fetch most recent task
        response = db.client.table("upload_tasks")\
            .select("*")\
            .eq("username", current_user.get("username"))\
            .eq("task_type", "sales")\
            .order("created_at", desc=True)\
            .limit(1)\
            .execute()
            
        if not response.data or len(response.data) == 0:
            # Return None instead of 404 to indicate no task without triggering error
            return None
            
        status_record = response.data[0]
        
        return {
            "task_id": status_record.get("task_id"),
            "status": status_record.get("status", "unknown"),
            "progress": status_record.get("progress", {}),
            "message": status_record.get("message", ""),
            "duplicates": status_record.get("duplicates") or [],
            "uploaded_r2_keys": status_record.get("uploaded_r2_keys") or []
        }
    except Exception as e:
        logger.error(f"Error fetching recent sales task: {e}")
        # Only raise 500 for actual errors
        raise HTTPException(status_code=500, detail=f"Failed to fetch recent task: {str(e)}")


class BatchDeleteRequest(BaseModel):
    receipt_numbers: List[str]

@router.post("/history/delete-batch")
async def delete_history_batch(
    request: BatchDeleteRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Delete a batch of receipts from review and staging tables.
    Used for deleting recent order lists.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="No username in token")
        
    try:
        db = get_database_client()
        total_deleted = 0
        
        tables_to_clean = [
            'invoices',              # Staging table
            'verification_dates',    # Review table for dates/receipts
            'verification_amounts'   # Review table for line items
        ]
        
        for receipt_number in request.receipt_numbers:
            # Clean up '#' prefix if present
            clean_receipt = str(receipt_number).replace('#', '')
            for table_name in tables_to_clean:
                try:
                    result = db.delete(table_name, {'username': username, 'receipt_number': clean_receipt})
                    if result:
                        deleted_count = len(result) if isinstance(result, list) else 1
                        total_deleted += deleted_count
                        logger.info(f"Deleted {deleted_count} records from {table_name} for receipt {clean_receipt}")
                except Exception as e:
                    logger.warning(f"Error cleaning {table_name} for receipt {clean_receipt}: {e}")
                    continue
                    
        return {
            "success": True,
            "message": f"Deleted records for {len(request.receipt_numbers)} receipts",
            "records_deleted": total_deleted
        }
    except Exception as e:
        logger.error(f"Error in deleting history batch: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete batch: {str(e)}")


def process_invoices_sync(
    task_id: str,
    file_keys: List[str],
    r2_bucket: str,
    username: str,
    force_upload: bool = False
):
    """
    Synchronous background task to process invoices
    1. Upload temp files to R2
    2. Process with Gemini
    3. Clean up temp files
    """
    import os
    import shutil
    
    # Fresh DB client for this background task to avoid HTTP/2 stale connection errors
    _task_db = create_fresh_database_client()

    # Helper to update DB status
    def update_db_status(status_update: Dict[str, Any]):
        try:
            status_update["updated_at"] = datetime.utcnow().isoformat()
            _task_db.update("upload_tasks", status_update, {"task_id": task_id})
        except Exception as e:
            logger.error(f"Failed to update task status in DB: {e}")

    # FILE LOGGING with UTF-8 encoding (fixes Windows Unicode errors)
    with open("process_debug.log", "a", encoding="utf-8") as f:
        f.write(f"\nBACKGROUND TASK STARTED\n")
        f.write(f"{datetime.now()}: Task ID: {task_id}\n")
        f.write(f"Files to process: {len(file_keys)}\n")
        f.write(f"Force upload: {force_upload}\n")
        f.write(f"Username: {username}\n\n")
    
    print(f"\n🔥🔥🔥 BACKGROUND TASK STARTED 🔥🔥🔥", flush=True)
    print(f"Task ID: {task_id}", flush=True)
    print(f"Files to process: {len(file_keys)}", flush=True)
    print(f"Force upload: {force_upload}", flush=True)
    print(f"{'='*80}\n", flush=True)
    
    logger.info(f"========== BACKGROUND TASK STARTED ==========")
    logger.info(f"Task ID: {task_id}")
    logger.info(f"File keys to process: {file_keys}")
    logger.info(f"User: {username}")
    logger.info(f"R2 Bucket: {r2_bucket}")
    logger.info(f"Force upload: {force_upload}")
    
    # Log environment check
    import os
    logger.info(f"Environment check:")
    logger.info(f"  - GOOGLE_API_KEY set: {bool(os.getenv('GOOGLE_API_KEY'))}")
    logger.info(f"  - CLOUDFLARE_R2_ACCOUNT_ID set: {bool(os.getenv('CLOUDFLARE_R2_ACCOUNT_ID'))}")
    logger.info(f"  - SUPABASE_URL set: {bool(os.getenv('SUPABASE_URL'))}")
    
    r2_file_keys = []
    
    # Initialize current status dict for local updates (efficiency)
    current_status = {
        "progress": {
            "total": len(file_keys),
            "processed": 0,
            "failed": 0
        }
    }
    
    try:
        # Phase 1: Upload (SKIPPED - Files are already in R2 from Phase 1)
        # Note: file_keys argument now contains R2 keys, not temp paths
        logger.info("Phase 1: Verifying files in R2...")
        
        update_db_status({
            "status": "uploading",
            "message": "Verifying cloud files...",
            "start_time": datetime.now().isoformat()
        })
        
        r2_file_keys = file_keys # They are already keys
        
        # Just update progress to 100% since upload is done
        current_status["progress"]["total"] = len(r2_file_keys)
        current_status["progress"]["processed"] = len(r2_file_keys)
        
        # Phase 2: Process invoices
        logger.info("Phase 2: Processing invoices with AI...")
        
        current_status["progress"]["processed"] = 0 # Reset for processing phase
        
        update_db_status({
            "status": "processing",
            "message": "Processing invoices...",
            "progress": current_status["progress"]
        })
        
        # Define progress callback
        def update_progress(current_index: int, failed_count: int, total: int, current_file: str):
            """Callback to update processing status in real-time"""
            current_status["progress"]["processed"] = current_index
            current_status["progress"]["failed"] = failed_count
            
            update_db_status({
                "progress": current_status["progress"],
                "current_file": current_file,
                "current_index": current_index,
                "message": f"Processing: {current_file}"
            })
            logger.info(f"Progress: {current_index}/{total} (Failed: {failed_count}) - {current_file}")
        
        # Import the processor
        from services.processor import process_invoices_batch
        
        logger.info(f"Processing {len(r2_file_keys)} files for user {username}")
        
        # Call the actual processor with R2 keys
        results = process_invoices_batch(
            file_keys=r2_file_keys,
            r2_bucket=r2_bucket,
            username=username,
            progress_callback=update_progress,
            force_upload=force_upload
        )
        
        logger.info(f"Processing completed. Results: {results}")
        
        # Build compact skipped summary list for mobile display
        duplicate_list = results.get("duplicates", [])
        skipped_count = len(duplicate_list)
        skipped_summary = []
        for dup in duplicate_list:
            existing = dup.get("existing_invoice", {})
            skipped_summary.append({
                "file_key": dup.get("file_key", ""),
                "receipt_number": existing.get("receipt_number", ""),
                "invoice_date": existing.get("date", ""),
                "message": "Already uploaded previously",
            })

        # Build human-readable completion message
        parts = []
        if results["processed"] > 0:
            parts.append(f"{results['processed']} invoice{'s' if results['processed'] != 1 else ''} processed")
        if results["failed"] > 0:
            parts.append(f"{results['failed']} failed")
        completion_msg = ", ".join(parts) if parts else "No invoices were processed"

        # Always mark completed — summary screen will show the breakdown
        update_db_status({
            "status": "completed",
            "progress": {
                "total": results["total"],
                "processed": results["processed"],
                "failed": results["failed"],
                "skipped": skipped_count,
                "skipped_details": skipped_summary,
                "errors": results.get("errors", []),
            },
            "duplicates": duplicate_list,   # keep for backwards-compat
            "uploaded_r2_keys": r2_file_keys,
            "end_time": datetime.now().isoformat(),
            "message": completion_msg,
            "current_file": "All complete",
        })

        if skipped_count:
            logger.info(f"Duplicates detected: {skipped_count}")

        # AUTO-RECALCULATION: Trigger stock recalculation after successful processing
        # This ensures stock levels are always up-to-date
        # Advisory locks prevent race conditions with concurrent recalculations
        # if results["processed"] > 0:
        #     logger.info(f"🔄 Auto-triggering stock recalculation for {username}...")
        #     try:
        #         from routes.stock_routes import recalculate_stock_wrapper
        #         
        #         # Create a task_id for tracking
        #         recalc_task_id = str(uuid.uuid4())
        #         
        #         # Initialize task in DB (required for wrapper updates)
        #         try:
        #             db = get_database_client()
        #             db.insert("recalculation_tasks", {
        #                 "task_id": recalc_task_id,
        #                 "username": username,
        #                 "status": "queued",
        #                 "message": "Auto-triggered after upload",
        #                 "progress": {"total": 0, "processed": 0},
        #                 "created_at": datetime.utcnow().isoformat()
        #             })
        #         except Exception as db_err:
        #             logger.warning(f"Could not create recalculation task record: {db_err}")
        #             # Proceed anyway, wrapper might fail on update but calculation might run
        #         
        #         # Run in background (uses stock_executor thread pool)
        #         # Pass BOTH task_id and username as required by wrapper
        #         recalculate_stock_wrapper(recalc_task_id, username)
        #         
        #         logger.info(f"✅ Stock recalculation queued for {username} (Task: {recalc_task_id})")
        #     except Exception as e:
        #         logger.error(f"❌ Auto-recalculation failed for {username}: {e}")
        #         # Don't fail the upload if recalculation fails
        #         # User can manually trigger recalculation later

        
        if results["errors"]:
            # Append errors to log or DB if we want?
            # update_db_status({"errors": results["errors"]})
            logger.warning(f"Processing errors: {results['errors']}")
        
    except Exception as e:
        logger.error(f"=== BACKGROUND TASK FAILED ===")
        logger.error(f"Error processing invoices: {e}")
        logger.error(f"Error type: {type(e).__name__}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        update_db_status({
            "status": "failed",
            "message": f"Processing failed: {str(e)}",
            "end_time": datetime.now().isoformat()
        })
    
    finally:
        # Phase 3: Cleanup (No temp files to clean up anymore)
        logger.info("=== BACKGROUND TASK COMPLETED ===")


@router.delete("/files/{file_key:path}")
async def delete_file(
    file_key: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    Delete a file from R2 storage
    """
    storage = get_storage_client()
    
    success = storage.delete_file(r2_bucket, file_key)
    
    if not success:
        raise HTTPException(status_code=500, detail="Failed to delete file")
    
    return {"success": True, "message": "File deleted successfully"}


@router.get("/files/view/{file_key:path}")
async def get_file_url(
    file_key: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    r2_bucket: str = Depends(get_current_user_r2_bucket)
):
    """
    Get permanent public URL for a file from R2 storage
    """
    from urllib.parse import unquote
    
    try:
        # Explicitly unquote the file_key to handle %2F correctly
        decoded_key = unquote(file_key)
        
        storage = get_storage_client()
        
        # Check if file exists first (optional but good for debugging)
        # if not storage.file_exists(r2_bucket, decoded_key):
        #    raise HTTPException(status_code=404, detail="File not found")
        
        # Generate permanent public URL
        url = storage.get_public_url(r2_bucket, decoded_key)
        
        if not url:
            # Fallback to r2:// path if public URL not configured, but this won't work in browser
            logger.warning(f"Public URL not configured for {decoded_key}")
            raise HTTPException(status_code=500, detail="Public URL not configured for R2 bucket")
        
        return {"url": url}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate public URL for {file_key}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate file URL: {str(e)}")
