"""
📊 Updated API Routes with Pagination
Replaces old endpoints with cursor-based paginated versions
"""
from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional, Dict, Any
import logging
from enum import Enum

from auth import get_current_user
from database import get_database_client
from utils.pagination import (
    PaginationParams, SortDirection, OptimizedQueries
)

logger = logging.getLogger(__name__)
router = APIRouter()


class InventorySortBy(str, Enum):
    """Allowed sort fields for inventory"""
    INVOICE_DATE = "invoice_date"
    CREATED_AT = "created_at"
    VENDOR_NAME = "vendor_name"
    INVOICE_NUMBER = "invoice_number"


class KhataSortBy(str, Enum):
    """Allowed sort fields for khata/parties"""
    BALANCE_DUE = "balance_due"
    UPDATED_AT = "updated_at"
    CUSTOMER_NAME = "customer_name"


# ════════════════════════════════════════════════════════════════════════════════
# INVENTORY ENDPOINTS - PAGINATED
# ════════════════════════════════════════════════════════════════════════════════

@router.get("/inventory/items")
async def get_inventory_items_paginated(
    limit: int = Query(20, ge=10, le=100, description="Items per page"),
    cursor: Optional[str] = Query(None, description="Pagination cursor"),
    sort_by: InventorySortBy = Query(InventorySortBy.INVOICE_DATE),
    sort_direction: str = Query("desc", regex="^(asc|desc)$"),
    search: Optional[str] = Query(None, description="Search product/vendor name"),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get paginated inventory items.
    
    Features:
    - Cursor-based pagination (efficient for large datasets)
    - Configurable sorting
    - Optional search filtering
    - Always returns in consistent format
    
    Usage:
    ```
    # First page
    GET /inventory/items?limit=20
    
    # Next page using cursor
    GET /inventory/items?limit=20&cursor=<next_cursor>
    ```
    """
    try:
        username = current_user['username']
        db = get_database_client()

        pagination_params = PaginationParams(
            limit=limit,
            cursor=cursor,
            sort_by=sort_by.value,
            sort_direction=SortDirection(sort_direction),
            search=search
        )

        result = OptimizedQueries.get_inventory_paginated(
            db.client, username, pagination_params
        )

        return result

    except Exception as e:
        logger.error(f"Error fetching inventory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/inventory/summary")
async def get_inventory_summary(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get quick summary stats (total items, total value, last updated).
    This is a lightweight endpoint for dashboard/header info.
    """
    try:
        username = current_user['username']
        db = get_database_client()

        # Fetch summary stats (this can be cached/aggregated in DB)
        response = db.client.table('inventory_items') \
            .select('id, created_at') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(1) \
            .execute()

        items = response.data or []
        if items:
            last_updated = items[0]['created_at']
        else:
            last_updated = None

        # Count total items
        count_response = db.client.table('inventory_items') \
            .select('id', count='exact') \
            .eq('username', username) \
            .execute()

        total_count = count_response.count or 0

        return {
            "total_items": total_count,
            "last_updated": last_updated,
            "status": "ready"
        }

    except Exception as e:
        logger.error(f"Error fetching inventory summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ════════════════════════════════════════════════════════════════════════════════
# KHATA ENDPOINTS - PAGINATED
# ════════════════════════════════════════════════════════════════════════════════

@router.get("/khata/parties")
async def get_khata_parties_paginated(
    limit: int = Query(20, ge=10, le=100),
    cursor: Optional[str] = Query(None),
    sort_by: KhataSortBy = Query(KhataSortBy.UPDATED_AT),
    sort_direction: str = Query("desc", regex="^(asc|desc)$"),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get paginated list of parties/customers with balance info.
    
    This replaces the old /khata endpoint with full pagination support.
    """
    try:
        username = current_user['username']
        db = get_database_client()

        pagination_params = PaginationParams(
            limit=limit,
            cursor=cursor,
            sort_by=sort_by.value,
            sort_direction=SortDirection(sort_direction)
        )

        result = OptimizedQueries.get_khata_parties_paginated(
            db.client, username, pagination_params
        )

        return result

    except Exception as e:
        logger.error(f"Error fetching khata parties: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/khata/parties/summary")
async def get_khata_parties_summary(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get quick summary of parties (total count, total balance, etc).
    Lightweight endpoint for dashboard display.
    """
    try:
        username = current_user['username']
        db = get_database_client()

        # Fetch all ledgers (consider caching this)
        response = db.client.table('customer_ledgers') \
            .select('id, balance_due') \
            .eq('username', username) \
            .execute()

        items = response.data or []
        total_count = len(items)
        total_balance = sum(item.get('balance_due', 0) for item in items)

        return {
            "total_parties": total_count,
            "total_balance_due": total_balance,
            "status": "ready"
        }

    except Exception as e:
        logger.error(f"Error fetching khata summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/khata/ledgers/{ledger_id}/transactions")
async def get_party_transactions_paginated(
    ledger_id: int,
    limit: int = Query(20, ge=10, le=100),
    cursor: Optional[str] = Query(None),
    sort_by: str = Query("transaction_date"),
    sort_direction: str = Query("desc", regex="^(asc|desc)$"),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get paginated transaction history for a specific party via ledger_id.
    Sorted by date (most recent first).
    """
    try:
        username = current_user['username']
        db = get_database_client()

        pagination_params = PaginationParams(
            limit=limit,
            cursor=cursor,
            sort_by=sort_by,
            sort_direction=SortDirection(sort_direction)
        )

        result = OptimizedQueries.get_khata_transactions_paginated(
            db.client, username, ledger_id, pagination_params
        )

        return result

    except Exception as e:
        logger.error(f"Error fetching party transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ════════════════════════════════════════════════════════════════════════════════
# TRACK ITEMS (UPLOADS) ENDPOINTS - PAGINATED
# ════════════════════════════════════════════════════════════════════════════════

@router.get("/uploads/tasks")
async def get_upload_tasks_paginated(
    limit: int = Query(20, ge=10, le=100),
    cursor: Optional[str] = Query(None),
    sort_by: str = Query("created_at"),
    sort_direction: str = Query("desc", regex="^(asc|desc)$"),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get paginated upload task history.
    Useful for tracking uploads and processing status.
    """
    try:
        username = current_user['username']
        db = get_database_client()

        pagination_params = PaginationParams(
            limit=limit,
            cursor=cursor,
            sort_by=sort_by,
            sort_direction=SortDirection(sort_direction)
        )

        result = OptimizedQueries.get_upload_tasks_paginated(
            db.client, username, pagination_params
        )

        return result

    except Exception as e:
        logger.error(f"Error fetching upload tasks: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/uploads/summary")
async def get_uploads_summary(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get quick summary of uploads (recent status, pending count, etc).
    """
    try:
        username = current_user['username']
        db = get_database_client()

        # Count pending uploads
        pending = db.client.table('upload_tasks') \
            .select('id', count='exact') \
            .eq('username', username) \
            .eq('status', 'processing') \
            .execute()

        # Get most recent upload
        recent = db.client.table('upload_tasks') \
            .select('*') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(1) \
            .execute()

        recent_data = recent.data[0] if recent.data else None

        return {
            "pending_count": pending.count or 0,
            "last_upload": recent_data,
            "status": "ready"
        }

    except Exception as e:
        logger.error(f"Error fetching uploads summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))
