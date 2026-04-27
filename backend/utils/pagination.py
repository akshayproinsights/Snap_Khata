"""
🚀 Advanced Pagination System for Top-1% SaaS
Handles massive datasets efficiently with cursor-based pagination
"""
from typing import TypeVar, Generic, List, Dict, Any, Optional, Callable
from pydantic import BaseModel, Field
from dataclasses import dataclass
from datetime import datetime
import base64
import json
from enum import Enum

T = TypeVar('T')


class SortDirection(str, Enum):
    """Sort direction enum"""
    ASC = "asc"
    DESC = "desc"


@dataclass
class PaginationCursor:
    """Cursor for pagination tracking"""
    last_id: str
    last_value: Any
    direction: SortDirection = SortDirection.DESC

    def encode(self) -> str:
        """Encode cursor to base64 string for URL safety"""
        data = {
            'last_id': self.last_id,
            'last_value': self.last_value,
            'direction': self.direction.value
        }
        return base64.b64encode(json.dumps(data).encode()).decode()

    @staticmethod
    def decode(cursor_str: str) -> 'PaginationCursor':
        """Decode cursor from base64 string"""
        try:
            data = json.loads(base64.b64decode(cursor_str.encode()).decode())
            return PaginationCursor(
                last_id=data['last_id'],
                last_value=data['last_value'],
                direction=SortDirection(data.get('direction', 'desc'))
            )
        except Exception:
            return None


class PaginatedResponse(BaseModel, Generic[T]):
    """Universal paginated response"""
    data: List[T] = Field(default_factory=list)
    total_count: int = 0  # Total records in DB (expensive for huge lists - optional)
    has_next: bool = False
    has_previous: bool = False
    next_cursor: Optional[str] = None
    previous_cursor: Optional[str] = None
    page_info: Dict[str, Any] = Field(default_factory=dict)  # Extra metadata


class PaginationParams:
    """Helper class for pagination parameters"""
    def __init__(
        self,
        limit: int = 20,
        cursor: Optional[str] = None,
        sort_by: str = "created_at",
        sort_direction: SortDirection = SortDirection.DESC,
        search: Optional[str] = None,
        filters: Optional[Dict[str, Any]] = None
    ):
        # Validate and cap limit
        self.limit = min(max(limit, 10), 100)  # 10-100 items per page
        self.cursor = cursor
        self.sort_by = sort_by
        self.sort_direction = sort_direction
        self.search = search
        self.filters = filters or {}

    def apply_to_query(self, query_builder):
        """Apply pagination to Supabase query builder"""
        # Apply sorting
        query_builder = query_builder.order(
            self.sort_by,
            desc=(self.sort_direction == SortDirection.DESC)
        )

        # Apply limit (fetch 1 extra to check if has_next)
        query_builder = query_builder.limit(self.limit + 1)

        # If cursor exists, apply range filter
        if self.cursor:
            try:
                cursor_obj = PaginationCursor.decode(self.cursor)
                if cursor_obj:
                    # For DESC order: get items less than cursor
                    # For ASC order: get items greater than cursor
                    if self.sort_direction == SortDirection.DESC:
                        query_builder = query_builder.lt(self.sort_by, cursor_obj.last_value)
                    else:
                        query_builder = query_builder.gt(self.sort_by, cursor_obj.last_value)
            except Exception:
                pass

        return query_builder


class PaginationHelper:
    """Helper methods for pagination"""

    @staticmethod
    def build_paginated_response(
        items: List[Dict[str, Any]],
        limit: int,
        sort_by: str,
        sort_direction: SortDirection,
        total_count: Optional[int] = None,
        include_total: bool = False
    ) -> Dict[str, Any]:
        """Build a paginated response from fetched items"""

        # Check if we fetched more than limit (indicates has_next)
        has_next = len(items) > limit
        if has_next:
            items = items[:limit]

        has_previous = False  # Would need previous_cursor to know this

        next_cursor = None
        if has_next and items:
            last_item = items[-1]
            next_cursor = PaginationCursor(
                last_id=str(last_item.get('id', '')),
                last_value=last_item.get(sort_by),
                direction=sort_direction
            ).encode()

        response_data = {
            'data': items,
            'has_next': has_next,
            'has_previous': has_previous,
            'next_cursor': next_cursor,
            'page_info': {
                'count': len(items),
                'sort_by': sort_by,
                'sort_direction': sort_direction.value,
            }
        }

        if include_total and total_count is not None:
            response_data['total_count'] = total_count

        return response_data

    @staticmethod
    def batch_fetch_with_pagination(
        db_client,
        table_name: str,
        username: str,
        limit: int = 50,
        batch_size: int = 1000,
        process_fn: Optional[Callable] = None
    ) -> List[Dict[str, Any]]:
        """
        Efficiently batch-fetch all records from a table.
        Use this when you need all records (for local filtering/processing).
        """
        all_items = []
        offset = 0

        while True:
            response = db_client.table(table_name) \
                .select('*') \
                .eq('username', username) \
                .range(offset, offset + batch_size - 1) \
                .execute()

            items = response.data or []
            if not items:
                break

            if process_fn:
                items = [process_fn(item) for item in items]

            all_items.extend(items)
            offset += batch_size

            if len(items) < batch_size:
                break

        return all_items

    @staticmethod
    def aggregate_before_pagination(
        items: List[Dict[str, Any]],
        group_by_field: str,
        aggregate_fn: Callable
    ) -> Dict[str, Any]:
        """
        For aggregated/grouped views (like inventory by product),
        do local aggregation then paginate the grouped results.
        """
        grouped = {}
        for item in items:
            key = item.get(group_by_field)
            if key not in grouped:
                grouped[key] = []
            grouped[key].append(item)

        return {
            group_key: aggregate_fn(group_items)
            for group_key, group_items in grouped.items()
        }


# ════════════════════════════════════════════════════════════════════════════════
# OPTIMIZED QUERIES FOR COMMON SCENARIOS
# ════════════════════════════════════════════════════════════════════════════════


class OptimizedQueries:
    """Pre-built optimized queries for common operations"""

    @staticmethod
    def get_inventory_paginated(
        db_client,
        username: str,
        pagination_params: PaginationParams
    ) -> Dict[str, Any]:
        """Get paginated inventory items with smart columns"""
        query = db_client.table('inventory_items') \
            .select(
                'id, invoice_number, vendor_name, invoice_date, '
                'quantity, rate, line_total, hsn_code, product_name'
            ) \
            .eq('username', username)

        # Apply search filter
        if pagination_params.search:
            # Search across product_name and vendor_name (index-optimized)
            search_term = pagination_params.search.lower()
            # Note: Supabase doesn't support full-text search by default
            # For production: implement Elasticsearch or use LIKE with indexes
            pass

        query = pagination_params.apply_to_query(query)
        response = query.execute()
        items = response.data or []

        return PaginationHelper.build_paginated_response(
            items,
            pagination_params.limit,
            pagination_params.sort_by,
            pagination_params.sort_direction
        )

    @staticmethod
    def get_khata_parties_paginated(
        db_client,
        username: str,
        pagination_params: PaginationParams
    ) -> Dict[str, Any]:
        """Get paginated party/customer list with balances"""
        query = db_client.table('customer_ledgers') \
            .select('id, customer_name, balance_due, total_due, updated_at') \
            .eq('username', username)

        query = pagination_params.apply_to_query(query)
        response = query.execute()
        items = response.data or []

        return PaginationHelper.build_paginated_response(
            items,
            pagination_params.limit,
            pagination_params.sort_by,
            pagination_params.sort_direction
        )

    @staticmethod
    def get_khata_transactions_paginated(
        db_client,
        username: str,
        ledger_id: int,
        pagination_params: PaginationParams
    ) -> Dict[str, Any]:
        """Get paginated transactions for a specific party via ledger_id"""
        query = db_client.table('ledger_transactions') \
            .select(
                'id, transaction_date, transaction_type, amount, '
                'receipt_number, notes, created_at'
            ) \
            .eq('username', username) \
            .eq('ledger_id', ledger_id)

        query = pagination_params.apply_to_query(query)
        response = query.execute()
        items = response.data or []

        return PaginationHelper.build_paginated_response(
            items,
            pagination_params.limit,
            pagination_params.sort_by,
            pagination_params.sort_direction
        )

    @staticmethod
    def get_upload_tasks_paginated(
        db_client,
        username: str,
        pagination_params: PaginationParams
    ) -> Dict[str, Any]:
        """Get paginated upload history/tracking"""
        query = db_client.table('upload_tasks') \
            .select(
                'id, status, created_at, file_count, '
                'processed_count, error_count, message'
            ) \
            .eq('username', username)

        query = pagination_params.apply_to_query(query)
        response = query.execute()
        items = response.data or []

        return PaginationHelper.build_paginated_response(
            items,
            pagination_params.limit,
            pagination_params.sort_by,
            pagination_params.sort_direction
        )
