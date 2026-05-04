"""
Database helper functions for route endpoints.
Provides clean interface for common Supabase queries.
"""
from typing import List, Dict, Any, Optional
import logging
import pandas as pd
from database import get_database_client

logger = logging.getLogger(__name__)


def flatten_extra_fields(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Flatten the 'extra_fields' JSONB column into the top level of each record.
    If a key in extra_fields already exists at the top level, the top level value wins.
    """
    for record in records:
        extra = record.get('extra_fields')
        if extra and isinstance(extra, dict):
            for key, value in extra.items():
                if key not in record:
                    record[key] = value
    return records



def convert_numeric_types(row_dict: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert numeric values to proper Python types for Supabase.
    - Integers without decimals: convert to int
    - Floats with decimals: convert to float
    - Remove .0 suffix from string representations
    """
    integer_fields = ['input_tokens', 'output_tokens', 'total_tokens']  # Industry-specific numeric fields are now in extra_fields
    float_fields = ['quantity', 'rate', 'amount', 'total_bill_amount', 'calculated_amount', 'amount_mismatch', 'received_amount', 'balance_due', 'model_accuracy', 'cost_inr']
    
    for key, value in row_dict.items():
        # test
        if isinstance(value, (dict, list)):
            continue
            
        if value is None or pd.isna(value):
            row_dict[key] = None
            continue
            
        # Handle integer fields
        if key in integer_fields:
            try:
                # Convert to float first, then to int
                row_dict[key] = int(float(value))
            except (ValueError, TypeError):
                row_dict[key] = None
        
        # Handle float fields
        elif key in float_fields:
            try:
                if isinstance(value, str):
                    value = value.replace(',', '').strip()
                row_dict[key] = float(value)
            except (ValueError, TypeError):
                row_dict[key] = None
        
        # Handle string fields that might be floats (e.g., "801.0" -> "801")
        elif isinstance(value, str) and value.endswith('.0'):
            try:
                # Check if it's a numeric string
                float_val = float(value)
                if float_val.is_integer():
                    row_dict[key] = value[:-2]  # Remove .0
            except ValueError:
                pass  # Keep as is if not numeric
    
    return row_dict



def get_all_invoices(username: str, limit: Optional[int] = None, offset: int = 0) -> List[Dict[str, Any]]:
    """
    Get all invoices for a user from Supabase.
    
    IMPORTANT: Supabase has a hard limit of 1000 records per query.
    This function automatically paginates to fetch ALL records.
    
    Args:
        username: Username for RLS filtering
        limit: Maximum number of records to return (if specified, uses single fetch)
        offset: Number of records to skip (only used when limit is specified)
    
    Returns:
        List of invoice dictionaries
    """
    try:
        db = get_database_client()
        
        # If a specific limit is requested, use simple pagination
        if limit is not None:
            query = db.query('invoices').eq('username', username).order('created_at', desc=True)
            query = query.limit(limit).offset(offset)
            result = query.execute()
            return result.data if result.data else []
        
        # Otherwise, fetch ALL records using pagination (for sync operations)
        all_records = []
        batch_size = 1000  # Supabase's maximum per request
        current_offset = 0
        
        logger.info(f"Fetching all invoice records for {username} (paginated)")
        
        while True:
            query = db.query('invoices').eq('username', username).order('created_at', desc=True)
            query = query.limit(batch_size).offset(current_offset)
            result = query.execute()
            
            if not result.data or len(result.data) == 0:
                break
            
            all_records.extend(result.data)
            logger.info(f"  Fetched batch {current_offset // batch_size + 1}: {len(result.data)} records (total so far: {len(all_records)})")
            
            # If we got less than batch_size records, we've reached the end
            if len(result.data) < batch_size:
                break
            
            current_offset += batch_size
        
        logger.info(f"✅ Fetched {len(all_records)} total invoice records for {username}")
        return all_records
    
    except Exception as e:
        logger.error(f"Error getting invoices for {username}: {e}")
        return []
    
    return flatten_extra_fields(all_records if limit is None else result.data)



def get_all_inventory(username: str, limit: Optional[int] = None) -> List[Dict[str, Any]]:
    """
    Get inventory items for a user.
    
    IMPORTANT: Supabase has a hard limit of 1000 records per query.
    
    Args:
        username: Username for RLS filtering
        limit: If specified, return only this many most recent records (single query, fast).
               If None, fetch ALL records using pagination (slower, but gets everything).
    
    Returns:
        List of inventory item dictionaries
    """
    try:
        db = get_database_client()
        
        # If limit is specified and <= 1000, use simple query (fast path)
        if limit is not None and limit <= 1000:
            logger.info(f"Fetching {limit} most recent inventory items for {username}")
            query = db.query('inventory').eq('username', username).order('upload_date', desc=True)
            query = query.limit(limit)
            result = query.execute()
            logger.info(f"✅ Fetched {len(result.data) if result.data else 0} inventory records")
            return result.data if result.data else []
        
        # Otherwise, fetch ALL records using pagination (for searches/filters)
        all_records = []
        batch_size = 1000  # Supabase's maximum per request
        current_offset = 0
        
        logger.info(f"Fetching ALL inventory records for {username} (paginated, for filtering)")
        
        while True:
            query = db.query('inventory').eq('username', username).order('upload_date', desc=True)
            query = query.limit(batch_size).offset(current_offset)
            result = query.execute()
            
            if not result.data or len(result.data) == 0:
                break
            
            all_records.extend(result.data)
            logger.info(f"  Fetched batch {current_offset // batch_size + 1}: {len(result.data)} records (total so far: {len(all_records)})")
            
            # If we got less than batch_size records, we've reached the end
            if len(result.data) < batch_size:
                break
            
            current_offset += batch_size
        
        logger.info(f"✅ Fetched {len(all_records)} total inventory records for {username}")
        return all_records
    
    except Exception as e:
        logger.error(f"Error getting inventory for {username}: {e}")
        return []


def get_verified_invoices(username: str, limit: Optional[int] = None) -> List[Dict[str, Any]]:
    """
    Get verified invoices for a user, sorted by upload_date descending.
    
    IMPORTANT: Supabase has a hard limit of 1000 records per query.
    
    Args:
        username: Username for RLS filtering
        limit: If specified, return only this many most recent records (single query, fast).
               If None, fetch ALL records using pagination (slower, but gets everything).
    
    Returns:
        List of verified invoice dictionaries
    """
    try:
        db = get_database_client()
        
        # If limit is specified and <= 1000, use simple query (fast path)
        if limit is not None and limit <= 1000:
            logger.info(f"Fetching {limit} most recent verified invoices for {username}")
            query = db.query('verified_invoices').eq('username', username).order('upload_date', desc=True).order('receipt_number').order('row_id')
            query = query.limit(limit)
            result = query.execute()
            logger.info(f"✅ Fetched {len(result.data) if result.data else 0} verified invoice records")
            return flatten_extra_fields(result.data) if result.data else []
        
        # Otherwise, fetch ALL records using pagination (for searches/filters)
        all_records = []
        batch_size = 1000  # Supabase's maximum per request
        current_offset = 0
        
        logger.info(f"Fetching ALL verified invoice records for {username} (paginated, for filtering)")
        
        while True:
            query = db.query('verified_invoices').eq('username', username).order('upload_date', desc=True).order('receipt_number').order('row_id')
            query = query.limit(batch_size).offset(current_offset)
            result = query.execute()
            
            if not result.data or len(result.data) == 0:
                break
            
            all_records.extend(result.data)
            logger.info(f"  Fetched batch {current_offset // batch_size + 1}: {len(result.data)} records (total so far: {len(all_records)})")
            
            # If we got less than batch_size records, we've reached the end
            if len(result.data) < batch_size:
                break
            
            current_offset += batch_size
        
        logger.info(f"✅ Fetched {len(all_records)} total verified invoice records for {username}")
        return all_records
    
    except Exception as e:
        logger.error(f"Error getting verified invoices for {username}: {e}")
        return []
        
    return flatten_extra_fields(all_records if limit is None else result.data)





def get_verification_dates(username: str) -> List[Dict[str, Any]]:
    """
    Get all date verification records for a user.
    
    Args:
        username: Username for RLS filtering
    
    Returns:
        List of verification date dictionaries
    """
    try:
        db = get_database_client()
        result = db.query('verification_dates').eq('username', username).order('created_at', desc=True).execute()
        return flatten_extra_fields(result.data) if result.data else []
    
    except Exception as e:
        logger.error(f"Error getting verification dates for {username}: {e}")
        return []


def get_verification_amounts(username: str) -> List[Dict[str, Any]]:
    """
    Get all amount verification records for a user.
    
    Args:
        username: Username for RLS filtering
    
    Returns:
        List of verification amount dictionaries (deduplicated by row_id)
    """
    try:
        db = get_database_client()
        # Sort by receipt_number to keep items together
        result = db.query('verification_amounts').eq('username', username).order('receipt_number').execute()
        records = flatten_extra_fields(result.data) if result.data else []
        
        # Deduplicate by id if needed
        seen_ids: dict = {}
        for record in records:
            # Fallback to a hash if id is missing, though Supabase should return id
            record_id = record.get('id')
            if record_id is not None:
                seen_ids[record_id] = record
            else:
                seen_ids[id(record)] = record
        
        deduplicated = list(seen_ids.values())
        
        if len(deduplicated) < len(records):
            logger.warning(
                f"⚠️ Deduplicated {len(records) - len(deduplicated)} duplicate "
                f"verification_amounts rows for {username}"
            )
        
        return deduplicated
    
    except Exception as e:
        logger.error(f"Error getting verification amounts for {username}: {e}")
        return []



def update_verified_invoices(username: str, data: List[Dict[str, Any]]) -> bool:
    """
    Update verified invoices using upsert (preserves existing records).
    
    Args:
        username: Username for RLS filtering
        data: List of invoice dictionaries to save
    
    Returns:
        True if successful, False otherwise
    """
    try:
        db = get_database_client()
        
        # Prepare records for batch upsert
        records = []
        
        # CORE columns that are guaranteed to exist in verified_invoices
        CORE_VERIFIED_COLS = {
            'username', 'receipt_number', 'date', 'description', 'amount', 
            'r2_file_path', 'image_hash', 'row_id', 'header_id', 'extra_fields',
            'line_item_row_bbox', 'model_used', 'model_accuracy', 
            'input_tokens', 'output_tokens', 'total_tokens', 'cost_inr',
            'receipt_link', 'type', 'customer_name', 'upload_date',
            'received_amount', 'balance_due', 'payment_mode', 'mobile_number',
            'customer_details', 'car_number', 'vehicle_number', 
            'total_bill_amount', 'gst_mode', 'odometer', 'quantity', 'rate',
            'taxable_row_ids'
        }
        
        # Columns for the raw 'invoices' table
        INVOICE_TABLE_COLS = {
            'id', 'created_at', 'username', 'receipt_number', 'date', 'customer', 
            'vehicle_number', 'description', 'amount', 'r2_file_path', 'image_hash', 
            'row_id', 'header_id', 'model_used', 'model_accuracy', 'input_tokens', 
            'output_tokens', 'total_tokens', 'cost_inr', 'extra_fields', 'receipt_link', 
            'quantity', 'rate', 'upload_date', 'fallback_attempted', 'fallback_reason', 
            'processing_errors', 'gst_mode', 'payment_mode', 'received_amount', 
            'balance_due', 'customer_details', 'taxable_row_ids', 'total_bill_amount'
        }
        
        verified_records = []
        raw_invoice_updates = []
        
        for record in data:
            record['username'] = username  # Ensure username is set
            
            # CRITICAL: Clean empty date strings
            if 'date' in record and (record['date'] == '' or pd.isna(record['date'])):
                record['date'] = None
                
            record = convert_numeric_types(record)
            
            # 1. Prepare record for verified_invoices
            extra_fields_verified = record.get('extra_fields', {})
            if not isinstance(extra_fields_verified, dict):
                extra_fields_verified = {}
            
            cleaned_verified = {}
            for k, v in record.items():
                if k in CORE_VERIFIED_COLS or k in ['id', 'row_id']:
                    cleaned_verified[k] = v
                elif v is not None:
                    extra_fields_verified[k] = v
            
            cleaned_verified['extra_fields'] = extra_fields_verified
            verified_records.append(cleaned_verified)

            # 2. Prepare record for raw invoices table (synchronization)
            if 'row_id' in record:
                extra_fields_raw = dict(extra_fields_verified)
                cleaned_raw = {}
                for k, v in record.items():
                    if k == 'customer_name' and 'customer' in INVOICE_TABLE_COLS:
                        cleaned_raw['customer'] = v
                    elif k in INVOICE_TABLE_COLS:
                        cleaned_raw[k] = v
                    elif v is not None and k not in ['id', 'extra_fields']:
                        extra_fields_raw[k] = v
                
                cleaned_raw['extra_fields'] = extra_fields_raw
                cleaned_raw['username'] = username
                cleaned_raw['row_id'] = record['row_id']
                raw_invoice_updates.append(cleaned_raw)
        
        # 1. Upsert to verified_invoices
        count_verified = db.batch_upsert('verified_invoices', verified_records, batch_size=500, on_conflict='username,row_id')
        logger.info(f"✅ Upserted {count_verified} verified invoices for {username}")
        
        # 2. Sync to raw invoices table (Optional but keeps data consistent)
        # Since invoices doesn't have a unique constraint on row_id, we update one by one or find IDs
        if raw_invoice_updates:
            try:
                # Find existing invoice IDs for these row_ids to perform targeted updates
                row_ids = [r['row_id'] for r in raw_invoice_updates]
                existing_resp = db.client.table('invoices').select('id, row_id').eq('username', username).in_('row_id', row_ids).execute()
                id_map = {row['row_id']: row['id'] for row in (existing_resp.data or [])}
                
                updates_with_ids = []
                for upd in raw_invoice_updates:
                    if upd['row_id'] in id_map:
                        upd['id'] = id_map[upd['row_id']]
                        updates_with_ids.append(upd)
                
                if updates_with_ids:
                    db.batch_upsert('invoices', updates_with_ids, batch_size=500)
                    logger.info(f"✅ Synced {len(updates_with_ids)} edits back to raw invoices table")
            except Exception as sync_err:
                logger.warning(f"Failed to sync edits back to raw invoices: {sync_err}")

        return True
    
    except Exception as e:
        logger.error(f"Error updating invoices for {username}: {e}")
        return False


def delete_records_by_receipt(username: str, receipt_number: str, table: str = 'verification_dates') -> bool:
    """
    Delete records by receipt number from a specific table.
    
    Args:
        username: Username for RLS filtering
        receipt_number: Receipt number to delete
        table: Table name ('verification_dates' or 'verification_amounts')
    
    Returns:
        True if successful, False otherwise
    """
    try:
        db = get_database_client()
        db.delete(table, {'username': username, 'receipt_number': receipt_number})
        logger.info(f"Deleted records for receipt {receipt_number} from {table}")
        return True
    
    except Exception as e:
        logger.error(f"Error deleting records from {table}: {e}")
        return False


def update_verification_records(username: str, table: str, data: List[Dict[str, Any]]) -> bool:
    """
    Update verification records (replace all for user).
    
    NOTE: This uses delete-all-then-batch-insert pattern intentionally!
    Verification tables need to remove "Done" records after Sync & Finish.
    The caller (verification.py) filters the data to only include records that should remain.
    
    Args:
        username: Username for RLS filtering
        table: Table name ('verification_dates' or 'verification_amounts')
        data: List of record dictionaries (already filtered to keep only Pending/Duplicate)
    
    Returns:
        True if successful, False otherwise
    """
    try:
        db = get_database_client()
        
        # Delete existing records for this user (removes "Done" records)
        db.delete(table, {'username': username})
        
        if not data:
            logger.info(f"No records to reinsert into {table} for {username} (all Done records removed)")
            return True
        
        # Prepare all records: set username, clean numeric types
        prepared = []
        for record in data:
            record = dict(record)  # Avoid mutating the caller's list
            record['username'] = username
            # Remove auto-generated fields that Supabase will re-assign on insert
            record.pop('id', None)
            record.pop('created_at', None)
            record = convert_numeric_types(record)
            prepared.append(record)
        
        # OPTIMIZED: Batch insert all remaining records in one Supabase call
        # This is 10-50x faster than per-record inserts and avoids Cloud Run timeout
        count = db.batch_upsert(table, prepared, batch_size=500)
        logger.info(f"✅ Reinserted {count} records into {table} for {username} (Done records removed)")
        return True
    
    except Exception as e:
        logger.error(f"Error updating {table} for {username}: {e}")
        return False
