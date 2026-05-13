"""
Supabase database client wrapper.
Handles all database operations for SnapKhata.
"""
import os
import time
from typing import Optional, Dict, Any, List, Tuple
import logging
from supabase import create_client, Client

from config import get_supabase_config

logger = logging.getLogger(__name__)

# Global Supabase client instance
_supabase_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """Get or create Supabase client instance"""
    global _supabase_client
    
    if _supabase_client is None:
        config = get_supabase_config()
        if not config:
            raise ValueError("Supabase configuration not found")
        
        _supabase_client = create_client(
            config["url"],
            config["service_role_key"]  # Use service_role for backend
        )
        logger.info("Supabase client initialized")
    
    return _supabase_client


class DatabaseClient:
    """Wrapper for Supabase database operations"""
    
    def __init__(self, client: Optional[Client] = None):
        self.client = client or get_supabase_client()
    
    def set_user_context(self, username: str):
        """Set user context for Row-Level Security"""
        # The backend uses service_role key which bypasses RLS.
        # Calling set_config is unnecessary and causes a noisy warning
        # since pg_catalog.set_config isn't exposed via PostgREST RPC.
        pass
    
    def query(self, table: str, columns: List[str] = None):
        """
        Query a table with optional column selection
        
        Args:
            table: Table name
            columns: List of column names to select (None = all)
        
        Returns:
            Query builder for further filtering
        """
        if columns:
            return self.client.table(table).select(','.join(columns))
        return self.client.table(table).select('*')
    
    def insert(self, table: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Insert a record"""
        response = self.client.table(table).insert(data).execute()
        return response.data

    def upsert(self, table: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Upsert a record"""
        response = self.client.table(table).upsert(data).execute()
        return response.data

    def upsert_with_retry(
        self,
        table: str,
        data: Dict[str, Any],
        max_retries: int = 3,
        base_delay: float = 1.0
    ) -> bool:
        """
        Upsert a single record with automatic retry on connection errors.

        Each retry uses a FRESH Supabase client to avoid reusing a stale
        HTTP/2 connection (the root cause of the 16-image data-loss incident).

        Args:
            table: Table name
            data: Row dict to upsert
            max_retries: Maximum number of attempts (default 3)
            base_delay: Base delay in seconds for exponential backoff

        Returns:
            True if upsert succeeded, False if all retries exhausted
        """
        last_error = None
        for attempt in range(max_retries):
            try:
                if attempt == 0:
                    # First attempt — use the current client (may be fresh or cached)
                    self.client.table(table).upsert(data).execute()
                else:
                    # Subsequent retries — always use a brand new connection
                    config = get_supabase_config()
                    fresh_client = create_client(config["url"], config["service_role_key"])
                    fresh_client.table(table).upsert(data).execute()
                return True  # Success
            except Exception as e:
                last_error = e
                delay = base_delay * (2 ** attempt)  # 1s, 2s, 4s
                row_id = data.get('row_id', 'unknown')
                logger.warning(
                    f"[RETRY {attempt + 1}/{max_retries}] upsert_with_retry failed for "
                    f"row '{row_id}' in '{table}': {e}. "
                    f"{'Retrying in ' + str(delay) + 's...' if attempt < max_retries - 1 else 'All retries exhausted.'}"
                )
                if attempt < max_retries - 1:
                    time.sleep(delay)

        logger.error(
            f"❌ upsert_with_retry: permanently failed for row '{data.get('row_id')}' "
            f"in '{table}' after {max_retries} attempts. Last error: {last_error}"
        )
        return False
    
    def batch_upsert(self, table: str, records: List[Dict[str, Any]], batch_size: int = 500, on_conflict: str = None) -> int:
        """
        Upsert records in batches for better performance
        
        Args:
            table: Table name
            records: List of records to upsert
            batch_size: Number of records per batch (default: 500)
            on_conflict: Column name(s) to use for conflict resolution (default: primary key)
        
        Returns:
            Total number of records processed
        """
        if not records:
            return 0
        
        total_processed = 0
        total_batches = (len(records) + batch_size - 1) // batch_size
        
        logger.info(f"Batch upserting {len(records)} records to '{table}' in {total_batches} batches")
        
        for i in range(0, len(records), batch_size):
            batch = records[i:i + batch_size]
            batch_num = (i // batch_size) + 1
            
            try:
                # Use onConflict parameter if specified (for unique constraints other than primary key)
                if on_conflict:
                    response = self.client.table(table).upsert(batch, on_conflict=on_conflict).execute()
                else:
                    response = self.client.table(table).upsert(batch).execute()
                    
                processed = len(response.data) if response.data else len(batch)
                total_processed += processed
                logger.debug(f"  Batch {batch_num}/{total_batches}: {processed} records")
            except Exception as e:
                logger.error(f"  Batch {batch_num}/{total_batches} failed: {e}")
                raise
        
        logger.info(f"✅ Batch upsert complete: {total_processed} records processed")
        return total_processed
    
    def update(self, table: str, data: Dict[str, Any], match: Dict[str, Any]) -> Dict[str, Any]:
        """Update records matching criteria"""
        response = self.client.table(table).update(data).match(match).execute()
        return response.data
    
    def delete(self, table: str, match: Dict[str, Any]) -> Dict[str, Any]:
        """Delete records matching criteria"""
        response = self.client.table(table).delete().match(match).execute()
        return response.data


# Global database client instance
_db_client: Optional[DatabaseClient] = None


def get_database_client() -> DatabaseClient:
    """Get global database client instance"""
    global _db_client
    if _db_client is None:
        _db_client = DatabaseClient()
    return _db_client


def create_fresh_database_client() -> DatabaseClient:
    """
    Create a brand-new Supabase client instance (not cached).

    Use this in background threads / long-running tasks to avoid
    the HTTP/2 'Server disconnected' error that occurs when the
    shared global client's connection goes stale during AI processing.
    """
    config = get_supabase_config()
    if not config:
        raise ValueError("Supabase configuration not found")
    fresh_client = create_client(config["url"], config["service_role_key"])
    return DatabaseClient(client=fresh_client)


def save_rows_with_retry(
    rows: List[Dict[str, Any]],
    table: str,
    excluded_columns: set,
    max_retries: int = 3
) -> Tuple[int, List[Dict[str, Any]]]:
    """
    Save a list of rows to the given table with per-row retry logic.

    This is the top-1% SaaS data-integrity guarantee:
    - Every row gets up to `max_retries` independent attempts.
    - Each retry uses a BRAND NEW Supabase HTTP connection.
    - Permanently-failed rows are returned to the caller for persistence
      (so they can be recovered later without re-running AI).

    Args:
        rows: List of row dicts to upsert
        table: Target Supabase table name
        excluded_columns: Set of column names to strip before upserting
        max_retries: Per-row retry attempts (default 3)

    Returns:
        Tuple of (saved_count, failed_rows)
        - saved_count: Number of rows successfully written
        - failed_rows: List of row dicts that could not be saved (for recovery)
    """
    saved_count = 0
    failed_rows: List[Dict[str, Any]] = []

    # Use a fresh client for the entire save batch — never the stale singleton
    # that was open during the long AI processing window.
    db = create_fresh_database_client()

    for row in rows:
        row_for_table = {k: v for k, v in row.items() if k not in excluded_columns}
        success = db.upsert_with_retry(table, row_for_table, max_retries=max_retries)
        if success:
            saved_count += 1
        else:
            failed_rows.append(row)  # Keep the FULL row (with all fields) for recovery

    return saved_count, failed_rows
