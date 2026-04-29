import logging
from datetime import datetime
from typing import List, Dict, Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import get_current_user
from database import get_database_client
from routes.vendor_ledgers import sync_vendor_ledgers_from_invoices

logger = logging.getLogger(__name__)

router = APIRouter()

# Schema for Payment
class PaymentCreate(BaseModel):
    amount: float
    notes: Optional[str] = None

async def process_ledgers_for_verified_invoices(username: str, final_records: List[Dict[str, Any]]):
    """
    Called from verification.py during Sync & Finish.
    Checks for credit records and updates customer ledgers and creates transactions.
    
    Now delegates to sync_customer_ledgers_from_invoices for consistent reconciliation.
    """
    if not final_records:
        return

    # Trigger a full sync for the user to reconcile everything, including renames and edits
    await sync_customer_ledgers_from_invoices({"username": username})

@router.get("/ledgers")
async def get_customer_ledgers(current_user: Dict = Depends(get_current_user)):
    """Get all customer ledgers for the current user, reconciled from transaction history."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Sync new invoices → ledgers before serving
        await sync_customer_ledgers_from_invoices(current_user)

        # Fetch all ledgers
        ledger_resp = db.client.table('customer_ledgers') \
            .select('*') \
            .eq('username', username) \
            .execute()
        
        ledgers = ledger_resp.data or []
        if not ledgers:
            return {"status": "success", "data": []}

        ledger_ids = [ld['id'] for ld in ledgers]

        # Fetch all transactions for these ledgers in one query
        tx_resp = db.client.table('ledger_transactions') \
            .select('ledger_id, amount, transaction_type') \
            .eq('username', username) \
            .in_('ledger_id', ledger_ids) \
            .execute()

        # Recompute expected balance for each ledger from transactions
        expected: Dict[int, float] = {ld['id']: 0.0 for ld in ledgers}
        for tx in (tx_resp.data or []):
            lid = tx.get('ledger_id')
            if lid not in expected:
                continue
            amt = float(tx.get('amount') or 0)
            ttype = tx.get('transaction_type')
            if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                expected[lid] += amt
            elif ttype == 'PAYMENT':
                expected[lid] -= amt

        # Patch stale balance_due values in DB and in-memory
        now = datetime.utcnow().isoformat()
        for ld in ledgers:
            lid = ld['id']
            stored = float(ld.get('balance_due') or 0)
            computed = expected[lid]
            if abs(stored - computed) > 0.01:
                try:
                    db.client.table('customer_ledgers').update({
                        'balance_due': computed,
                        'updated_at': now,
                    }).eq('id', lid).execute()
                    ld['balance_due'] = computed
                except Exception as patch_err:
                    logger.warning(f"Could not patch balance for ledger {lid}: {patch_err}")

        # Sort by balance_due descending (highest owed first)
        ledgers.sort(key=lambda x: float(x.get('balance_due') or 0), reverse=True)

        return {
            "status": "success",
            "data": ledgers
        }
    except Exception as e:
        logger.error(f"Error fetching ledgers: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/ledgers/{ledger_id}/transactions")
async def get_ledger_transactions(ledger_id: int, current_user: Dict = Depends(get_current_user)):
    """Get transaction history for a specific ledger."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Verify ledger belongs to user
        ledger_resp = db.client.table('customer_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Ledger not found")
            
        ledger = ledger_resp.data[0]
        
        # Get transactions
        tx_resp = db.client.table('ledger_transactions') \
            .select('*') \
            .eq('ledger_id', ledger_id) \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .execute()
            
        raw_transactions = tx_resp.data
        
        # Deduplicate INVOICE transactions (to handle any existing duplicate data)
        transactions = []
        seen_receipts = set()
        for tx in raw_transactions:
            if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number'):
                rn = tx['receipt_number']
                if rn in seen_receipts:
                    continue
                seen_receipts.add(rn)
            transactions.append(tx)
            
        enriched_transactions = []
        
        # Enrich INVOICE transactions with true grand_total and received_amount
        receipt_numbers = [tx['receipt_number'] for tx in transactions if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number')]
        
        enrichment = {}
        if receipt_numbers:
            # We safely query verified_invoices to reconstruct the actual invoice bill and initial payment
            vi_resp = db.client.table('verified_invoices').select('receipt_number, amount, received_amount, balance_due, payment_mode, receipt_link').in_('receipt_number', receipt_numbers).eq('username', username).execute()
            
            for vi in vi_resp.data:
                rn = vi.get('receipt_number')
                if not rn:
                    continue
                if rn not in enrichment:
                    enrichment[rn] = {'amount_sum': 0.0, 'received_amount': 0.0, 'balance_due': 0.0, 'payment_mode': 'Cash', 'receipt_link': ''}
                enrichment[rn]['amount_sum'] += float(vi.get('amount', 0) or 0)
                # Take the max non-zero value across rows (balance_due/received_amount may only be on one row)
                row_received = float(vi.get('received_amount', 0) or 0)
                row_balance = float(vi.get('balance_due', 0) or 0)
                if row_received > enrichment[rn]['received_amount']:
                    enrichment[rn]['received_amount'] = row_received
                if row_balance > enrichment[rn]['balance_due']:
                    enrichment[rn]['balance_due'] = row_balance
                if vi.get('payment_mode'):
                    enrichment[rn]['payment_mode'] = vi['payment_mode']
                if vi.get('receipt_link'):
                    enrichment[rn]['receipt_link'] = vi['receipt_link']
                
        for i, tx in enumerate(transactions):
            if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number') in enrichment:
                enr = enrichment[tx['receipt_number']]
                line_item_total = enr['amount_sum']
                
                # Determine effective values
                meta_received = float(enr.get('received_amount') or 0)
                meta_balance = float(enr.get('balance_due') or 0)
                payment_mode = enr.get('payment_mode') or 'Cash'
                
                # 1. Calculate grand_total: use metadata if sum > 0, else line items
                grand_total = meta_received + meta_balance
                if grand_total == 0 and line_item_total > 0:
                    grand_total = line_item_total
                
                # 2. Determine effective financial state
                if payment_mode.lower() != 'credit':
                    # Cash, Online, etc. are treated as fully paid if balance is 0 or metadata missing
                    effective_received = meta_received if (meta_received > 0 or meta_balance > 0) else grand_total
                    effective_balance = max(0, grand_total - effective_received)
                    is_paid = (effective_balance <= 0)
                else:
                    # Credit: handle missing metadata (both 0)
                    if meta_received == 0 and meta_balance == 0 and line_item_total > 0:
                        effective_received = 0.0
                        effective_balance = line_item_total
                        is_paid = False
                    else:
                        effective_received = meta_received
                        effective_balance = meta_balance
                        is_paid = (meta_balance <= 0)
                
                enriched_tx = dict(tx)
                enriched_tx['amount'] = grand_total
                enriched_tx['receipt_link'] = enr.get('receipt_link') or ''
                enriched_tx['is_paid'] = is_paid
                enriched_tx['balance_due'] = effective_balance
                enriched_tx['received_amount'] = effective_received
                enriched_transactions.append(enriched_tx)
                
                # If there was an initial payment, construct a dummy PAYMENT transaction
                if effective_received > 0:
                    dummy_payment = {
                        # Use a predictable negative ID bounded by loop index to avoid React/Flutter key collisions
                        'id': -(tx['id'] * 1000 + i), 
                        'ledger_id': ledger_id,
                        'transaction_type': 'PAYMENT',
                        'amount': effective_received,
                        'receipt_number': tx['receipt_number'],
                        'notes': f"Initial payment for Invoice {tx['receipt_number']}",
                        'created_at': tx['created_at'],
                        'is_paid': False,
                        'linked_transaction_id': None # Standalone so it is visible
                    }
                    enriched_transactions.append(dummy_payment)
            else:
                enriched_transactions.append(tx)
                
        # Re-sort because injected dummy payments will be out of order
        enriched_transactions.sort(key=lambda x: x['created_at'], reverse=True)
        
        # Recompute ledger summary from enriched transactions to ensure consistency
        computed_total_billed = 0.0
        computed_total_paid = 0.0
        
        for tx in enriched_transactions:
            amt = float(tx.get('amount') or 0)
            ttype = tx.get('transaction_type')
            if ttype == 'INVOICE':
                computed_total_billed += amt
                # If the invoice is enriched with received_amount, that's part of paid
                computed_total_paid += float(tx.get('received_amount') or 0)
            elif ttype == 'MANUAL_CREDIT':
                computed_total_billed += amt
            elif ttype == 'PAYMENT':
                # Note: dummy payments are already accounted for in received_amount above?
                # Actually, dummy payments are added to the list. 
                # Let's be careful not to double count.
                # If we use the enriched_transactions list, we should only count INVOICE + MANUAL_CREDIT vs PAYMENT.
                pass

        # Robust calculation: Sum of all INVOICE/MANUAL_CREDIT amounts minus all PAYMENT amounts
        # We'll use the final list which includes dummy payments.
        final_billed = 0.0
        final_paid = 0.0
        for tx in enriched_transactions:
            amt = float(tx.get('amount') or 0)
            ttype = tx.get('transaction_type')
            if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                final_billed += amt
            elif ttype == 'PAYMENT':
                final_paid += amt
        
        ledger['balance_due'] = max(0, final_billed - final_paid)
        # Add extra info for the UI header
        ledger['total_billed'] = final_billed
        ledger['total_paid'] = final_paid

        return {
            "status": "success",
            "ledger": ledger,
            "data": enriched_transactions
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching ledger transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/transactions/all")
async def get_all_customer_transactions(limit: int = 50, current_user: Dict = Depends(get_current_user)):
    """Get all customer transactions for the current user across all ledgers.
    
    Enriches INVOICE transactions with verified_invoices metadata (receipt_link,
    date, mobile_number, payment_mode, balance_due) so the mobile dashboard can
    navigate directly to OrderDetailPage without additional API calls.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # 1. Fetch latest ledger transactions
        response = db.client.table('ledger_transactions') \
            .select('*, customer_ledgers(customer_name, balance_due)') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(limit) \
            .execute()
        ledger_txs = response.data or []

        # Collect unique receipt_numbers from INVOICE transactions in ledger
        ledger_receipt_numbers = {
            tx['receipt_number']
            for tx in ledger_txs
            if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number')
        }

        # 2. Fetch latest verified invoices (Cash, etc.)
        vi_resp = db.client.table('verified_invoices') \
            .select('receipt_number') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(limit) \
            .execute()
        recent_vi_rns = {row['receipt_number'] for row in (vi_resp.data or []) if row.get('receipt_number')}

        # 3. Fetch full items for all relevant receipt numbers
        all_rns = ledger_receipt_numbers | recent_vi_rns
        
        invoice_items_map: Dict[str, List[Dict]] = {}
        invoice_meta: Dict[str, Dict] = {}

        if all_rns:
            try:
                # Fetch all rows for these receipt numbers to ensure we get every line item
                all_vi_resp = db.client.table('verified_invoices') \
                    .select('*') \
                    .eq('username', username) \
                    .in_('receipt_number', list(all_rns)) \
                    .execute()
                
                for vi in (all_vi_resp.data or []):
                    rn = vi.get('receipt_number')
                    if rn:
                        if rn not in invoice_items_map:
                            invoice_items_map[rn] = []
                        invoice_items_map[rn].append(vi)
                        # Keep the latest or first as meta
                        if rn not in invoice_meta:
                            invoice_meta[rn] = vi
            except Exception as e:
                logger.warning(f"Error fetching full items for verified_invoices: {e}")

        unified_txs = []

        # Inject metadata and items into each ledger transaction
        for tx in ledger_txs:
            rn = tx.get('receipt_number')
            if tx.get('transaction_type') == 'INVOICE' and rn and rn in invoice_meta:
                meta = invoice_meta[rn]
                items = invoice_items_map.get(rn, [])
                
                # Compute accurate total from line items (reliable even when balance_due not stored)
                items_total = sum(float(i.get('amount') or 0) for i in items)
                # Determine accurate total and effective financial state
                meta_received = float(meta.get('received_amount') or 0)
                meta_balance = float(meta.get('balance_due') or 0)
                payment_mode = meta.get('payment_mode') or 'Cash'
                
                grand_total = meta_received + meta_balance
                if grand_total == 0 and items_total > 0:
                    grand_total = items_total

                if payment_mode.lower() != 'credit':
                    # Cash/Online: default to fully paid if metadata missing
                    effective_received = meta_received if (meta_received > 0 or meta_balance > 0) else grand_total
                    effective_balance = max(0, grand_total - effective_received)
                    effective_is_paid = (effective_balance <= 0)
                else:
                    # Credit: handle missing metadata
                    if meta_received == 0 and meta_balance == 0 and items_total > 0:
                        effective_received = 0.0
                        effective_balance = items_total
                        effective_is_paid = False
                    else:
                        effective_received = meta_received
                        effective_balance = meta_balance
                        effective_is_paid = (meta_balance <= 0)
                
                # Fix amount=0 stored in ledger_transactions
                if float(tx.get('amount') or 0) == 0 and grand_total > 0:
                    tx['amount'] = grand_total
                
                tx['receipt_link'] = meta.get('receipt_link') or ''
                tx['invoice_date'] = meta.get('date') or ''
                tx['upload_date'] = meta.get('upload_date') or ''
                tx['mobile_number'] = str(meta.get('mobile_number') or '')
                tx['vehicle_number'] = meta.get('vehicle_number') or ''
                tx['customer_details'] = meta.get('customer_details') or ''
                tx['gst_mode'] = meta.get('gst_mode') or 'none'
                tx['type'] = meta.get('type') or 'Credit'
                tx['payment_mode'] = payment_mode
                tx['invoice_balance_due'] = effective_balance
                tx['received_amount'] = effective_received
                tx['is_paid'] = effective_is_paid
                tx['items'] = items
                if not (tx.get('customer_ledgers') or {}).get('customer_name'):
                    tx['_enriched_customer_name'] = meta.get('customer_name') or ''
                # Use upload_date as the activity timestamp for INVOICE txs.
                # This ensures recently processed invoices appear at the top
                # regardless of the invoice's own date field.
                upload_ts = meta.get('upload_date') or ''
                tx['activity_ts'] = upload_ts if upload_ts else tx.get('created_at') or ''
            else:
                tx.setdefault('receipt_link', '')
                tx.setdefault('invoice_date', '')
                tx.setdefault('upload_date', '')
                tx.setdefault('mobile_number', '')
                tx.setdefault('items', [])
                # For PAYMENT transactions, created_at IS the actual activity time.
                tx['activity_ts'] = tx.get('created_at') or ''
            unified_txs.append(tx)

        # 4. Add verified invoices that are NOT in ledger_txs
        # Group by receipt_number so that multi-item Cash invoices appear as ONE entry
        grouped_cash_invoices: Dict[str, Dict] = {}
        for rn, items in invoice_items_map.items():
            if rn in ledger_receipt_numbers:
                continue  # Skip credit invoices (already handled above via ledger_txs)

            first_item = items[0]
            total_amount = sum(float(i.get('amount') or 0.0) for i in items)
            
            # Use LATEST upload_date as the activity timestamp for cash invoices.
            # This ensures newly processed cash invoices appear at the top.
            upload_timestamps = [i.get('upload_date') for i in items if i.get('upload_date')]
            latest_upload_ts = max(upload_timestamps) if upload_timestamps else None

            # Fallback to latest created_at (DB insert time) if upload_date is missing
            created_timestamps = [i.get('created_at') for i in items if i.get('created_at')]
            latest_created_ts = max(created_timestamps) if created_timestamps else first_item.get('created_at')

            activity_ts = latest_upload_ts or latest_created_ts or ''
            
            # Find valid receipt_link and mobile_number
            receipt_link = next((i.get('receipt_link') for i in items if i.get('receipt_link')), '')
            mobile_number = str(next((i.get('mobile_number') for i in items if i.get('mobile_number')), ''))

            grouped_cash_invoices[rn] = {
                'id': first_item.get('id', 0),
                'ledger_id': None,
                'username': username,
                'transaction_type': 'INVOICE',
                'amount': total_amount,
                'notes': first_item.get('notes') or '',
                'receipt_number': rn,
                'created_at': latest_created_ts,
                'activity_ts': activity_ts,
                'is_paid': True,
                'receipt_link': receipt_link,
                'invoice_date': first_item.get('date') or '',
                'upload_date': first_item.get('upload_date') or '',
                'mobile_number': mobile_number,
                'payment_mode': first_item.get('payment_mode') or 'Cash',
                'invoice_balance_due': float(first_item.get('balance_due') or 0.0),
                'received_amount': float(first_item.get('received_amount') or total_amount or 0.0),
                'vehicle_number': first_item.get('vehicle_number') or '',
                'customer_details': first_item.get('customer_details') or '',
                'gst_mode': first_item.get('gst_mode') or 'none',
                'type': first_item.get('type') or 'Cash',
                '_enriched_customer_name': first_item.get('customer_name') or '',
                'customer_ledgers': {
                    'customer_name': first_item.get('customer_name') or '',
                    'balance_due': 0.0
                },
                'items': items
            }

        unified_txs.extend(grouped_cash_invoices.values())

        # Sort combined list by activity_ts descending.
        # activity_ts = upload_date for INVOICE records (when it was processed),
        # and created_at for PAYMENT records (when payment was actually made).
        # This ensures: recent uploads > recent payments > old invoices.
        unified_txs.sort(key=lambda x: x.get('activity_ts') or x.get('created_at') or '', reverse=True)

        return {
            "status": "success",
            "data": unified_txs[:limit]
        }
    except Exception as e:
        logger.error(f"Error fetching all customer transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/ledgers/{ledger_id}")
async def delete_customer_ledger(ledger_id: int, current_user: Dict = Depends(get_current_user)):
    """Delete a customer ledger and its transactions."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Verify ledger belongs to user
        ledger_resp = db.client.table('customer_ledgers') \
            .select('id, customer_name') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Ledger not found")
            
        customer_name = ledger_resp.data[0].get('customer_name')
            
        # Delete the ledger (transactions will be deleted by CASCADE)
        db.client.table('customer_ledgers').delete().eq('id', ledger_id).execute()
        
        # Prevent "Sync & Finish" from resurrecting this deleted ledger by
        # converting active credit invoices for this customer to Cash.
        if customer_name:
            try:
                db.client.table('invoices') \
                    .update({'payment_mode': 'Cash', 'balance_due': 0}) \
                    .eq('username', username) \
                    .eq('customer', customer_name) \
                    .eq('payment_mode', 'Credit') \
                    .execute()
                    
                db.client.table('verification_dates') \
                    .update({'payment_mode': 'Cash', 'balance_due': 0}) \
                    .eq('username', username) \
                    .eq('customer_details', customer_name) \
                    .eq('payment_mode', 'Credit') \
                    .execute()
                    
                db.client.table('verified_invoices') \
                    .update({'payment_mode': 'Cash', 'balance_due': 0}) \
                    .eq('username', username) \
                    .eq('customer_name', customer_name) \
                    .eq('payment_mode', 'Credit') \
                    .execute()
            except Exception as update_err:
                logger.warning(f"Failed to clear credit status on invoices when deleting ledger: {update_err}")
        
        return {
            "status": "success",
            "message": "Ledger deleted successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting ledger: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/ledgers/{ledger_id}/pay")
async def record_payment(ledger_id: int, payment: PaymentCreate, current_user: Dict = Depends(get_current_user)):
    """Record a payment from the customer, reducing their balance."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    if payment.amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be greater than zero")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        ledger_resp = db.client.table('customer_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Ledger not found")
            
        ledger = ledger_resp.data[0]
        current_balance = float(ledger.get('balance_due', 0))
        
        new_balance = current_balance - payment.amount
        now = datetime.utcnow().isoformat()
        
        db.client.table('customer_ledgers').update({
            'balance_due': new_balance,
            'last_payment_date': now,
            'updated_at': now
        }).eq('id', ledger_id).execute()
        
        db.client.table('ledger_transactions').insert({
            'username': username,
            'ledger_id': ledger_id,
            'transaction_type': 'PAYMENT',
            'amount': payment.amount,
            'notes': payment.notes
        }).execute()
        
        return {
            "status": "success",
            "message": "Payment recorded successfully",
            "new_balance": new_balance
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error recording payment: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class ManualUdharEntry(BaseModel):
    party_type: str # 'customer' or 'vendor'
    party_name: str # Name of the customer or vendor
    amount: float   # Must be > 0
    entry_type: str # 'got' (You Got) or 'gave' (You Gave)
    notes: Optional[str] = None

async def sync_customer_ledgers_from_invoices(current_user: Dict):
    """
    Reconcile customer_ledgers against verified_invoices.
    Scans all verified_invoices and ensures a matching customer_ledger + INVOICE transaction exists.
    Updates existing transactions if amount, payment_mode, or customer_name changed.
    """
    username = current_user.get("username")
    if not username:
        return

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all verified invoices
        invoices_resp = db.client.table("verified_invoices") \
            .select("id, receipt_number, date, customer_name, customer_details, amount, received_amount, balance_due, payment_mode, created_at, car_number, vehicle_number, extra_fields, mobile_number") \
            .eq("username", username) \
            .execute()

        invoices = invoices_resp.data or []
        if not invoices:
            return

        receipt_numbers = list(set([inv["receipt_number"] for inv in invoices if inv.get("receipt_number")]))

        # Group invoices by receipt number to handle multi-line invoices
        grouped_invoices = {}
        for inv in invoices:
            rn = inv.get("receipt_number")
            if not rn: continue
            
            if rn not in grouped_invoices:
                raw_name = str(inv.get("customer_name") or "").strip()
                raw_details = str(inv.get("customer_details") or "").strip()
                
                # Determine final name for grouping/ledger
                final_name = inv.get("customer_name")
                if not raw_name or raw_name.lower() in ['unknown', 'unknown customer', 'cash customer', '—', '-', 'null']:
                    final_name = raw_details if raw_details else raw_name

                grouped_invoices[rn] = {
                    "total_amount": 0.0,
                    "received_amount": float(inv.get("received_amount") or 0),
                    "balance_due": float(inv.get("balance_due") or 0),
                    # payment_mode is a header-level field — take from first line item
                    "payment_mode": inv.get("payment_mode") or "Cash",
                    "customer_name": final_name,
                    "date": inv.get("date") or inv.get("created_at"),
                    "notes": inv.get("customer_details"),
                    "car_number": inv.get("car_number") or inv.get("vehicle_number"),
                    "extra_fields": inv.get("extra_fields") or {},
                    "mobile_number": inv.get("mobile_number")
                }
            
            grouped_invoices[rn]["total_amount"] += float(inv.get("amount") or 0)
            
            # Ensure we keep the latest metadata if multiple lines have different metadata
            if inv.get("car_number") or inv.get("vehicle_number"):
                grouped_invoices[rn]["car_number"] = inv.get("car_number") or inv.get("vehicle_number")
            if inv.get("extra_fields"):
                grouped_invoices[rn]["extra_fields"].update(inv.get("extra_fields"))
            if inv.get("mobile_number"):
                grouped_invoices[rn]["mobile_number"] = inv.get("mobile_number")
            # payment_mode: if any line on the invoice is Credit, treat whole invoice as Credit
            existing_pm = grouped_invoices[rn].get("payment_mode", "Cash")
            incoming_pm = inv.get("payment_mode") or "Cash"
            if incoming_pm.strip().lower() == "credit":
                grouped_invoices[rn]["payment_mode"] = incoming_pm
            elif existing_pm.strip().lower() == "cash" and incoming_pm:
                grouped_invoices[rn]["payment_mode"] = incoming_pm
            
            # DEBUG: Log if we have mobile number
            if grouped_invoices[rn].get("mobile_number"):
                logger.debug(f"🔍 Found mobile_number for receipt {rn}: {grouped_invoices[rn]['mobile_number']}")
            else:
                logger.debug(f"ℹ️ No mobile_number for receipt {rn} yet")

        # 2. Fetch all existing ledgers and ensure new ones exist
        customer_names = list(set([g["customer_name"] for g in grouped_invoices.values() if g["customer_name"]]))
        
        ledgers_resp = db.client.table("customer_ledgers") \
            .select("id, customer_name") \
            .eq("username", username) \
            .in_("customer_name", customer_names) \
            .execute()

        ledger_map = {str(row["customer_name"]).strip().lower(): row["id"] for row in (ledgers_resp.data or [])}
        
        for name in customer_names:
            key = str(name).strip().lower()
            if key not in ledger_map:
                new_ledger_resp = db.client.table("customer_ledgers").insert({
                    "username": username,
                    "customer_name": name,
                    "balance_due": 0.0,
                }).execute()
                if new_ledger_resp.data:
                    ledger_map[key] = new_ledger_resp.data[0]["id"]

        # 3. Fetch existing transactions for these receipt numbers
        receipt_numbers = list(grouped_invoices.keys())
        existing_tx_resp = db.client.table("ledger_transactions") \
            .select("id, receipt_number, ledger_id, amount, is_paid, payment_mode, transaction_type, car_number, extra_fields, notes, created_at") \
            .eq("username", username) \
            .in_("receipt_number", receipt_numbers) \
            .execute()

        existing_invoices = {}
        existing_payments = {}
        for tx in (existing_tx_resp.data or []):
            rn = tx.get("receipt_number")
            if not rn: continue
            if tx["transaction_type"] == "INVOICE":
                existing_invoices[rn] = tx
            elif tx["transaction_type"] == "PAYMENT":
                existing_payments[rn] = tx

        now = datetime.utcnow().isoformat()
        
        for rn, data in grouped_invoices.items():
            customer_name = data["customer_name"]
            key = str(customer_name).strip().lower()
            ledger_id = ledger_map.get(key)
            if not ledger_id: continue

            # 1. Handle the INVOICE transaction (Full billing amount)
            total_amount = data["total_amount"]
            payment_mode = data.get("payment_mode") or "Cash"
            is_credit = payment_mode.strip().lower() == "credit"
            
            # Compute is_paid correctly based on payment_mode:
            # - Credit: paid only when balance_due is 0 (i.e. fully settled)
            # - Cash/Online: always treated as paid at time of invoice
            if is_credit:
                balance_due = data.get("balance_due", total_amount - data["received_amount"])
                is_paid_status = balance_due <= 0.01
            else:
                is_paid_status = True
            
            if rn in existing_invoices:
                tx = existing_invoices[rn]
                update_data = {}
                if tx["ledger_id"] != ledger_id: update_data["ledger_id"] = ledger_id
                if abs(float(tx.get("amount") or 0) - total_amount) > 0.01: 
                    update_data["amount"] = total_amount
                if bool(tx.get("is_paid")) != is_paid_status: 
                    update_data["is_paid"] = is_paid_status
                # Always sync payment_mode — this is the core fix
                if tx.get("payment_mode") != payment_mode:
                    update_data["payment_mode"] = payment_mode
                    logger.info(f"🔄 Updating payment_mode for receipt {rn}: {tx.get('payment_mode')!r} → {payment_mode!r}")
                
                # Sync metadata
                if tx.get("car_number") != data["car_number"]:
                    update_data["car_number"] = data["car_number"]
                    update_data["vehicle_number"] = data["car_number"]
                if tx.get("notes") != data["notes"]:
                    update_data["notes"] = data["notes"]
                
                # Sync date (created_at in ledger_transactions represents the transaction date)
                new_date = data.get("date")
                if new_date and tx.get("created_at") != new_date:
                    update_data["created_at"] = new_date
                
                # Merge mobile_number into extra_fields for ledger_transactions
                current_extra = tx.get("extra_fields") or {}
                new_extra = dict(data["extra_fields"])
                if data.get("mobile_number"):
                    new_extra["mobile_number"] = str(data["mobile_number"])
                    logger.debug(f"✅ Propagating mobile_number {new_extra['mobile_number']} to ledger_transactions for receipt {rn}")
                else:
                    logger.debug(f"⚠️ Missing mobile_number for receipt {rn} during ledger sync")
                
                if current_extra != new_extra:
                    update_data["extra_fields"] = new_extra
                    
                if update_data:
                    db.client.table("ledger_transactions").update(update_data).eq("id", tx["id"]).execute()
                else:
                    # Optional logging for debugging specific receipts
                    pass
            else:
                # Prepare extra_fields including mobile_number
                final_extra = dict(data["extra_fields"])
                if data.get("mobile_number"):
                    final_extra["mobile_number"] = str(data["mobile_number"])

                db.client.table("ledger_transactions").insert({
                    "username": username,
                    "ledger_id": ledger_id,
                    "transaction_type": "INVOICE",
                    "amount": total_amount,
                    "receipt_number": rn,
                    "is_paid": is_paid_status,
                    "payment_mode": payment_mode,
                    "created_at": data["date"] or now,
                    "notes": data["notes"],
                    "car_number": data["car_number"],
                    "vehicle_number": data["car_number"],
                    "extra_fields": final_extra
                }).execute()

            # 2. Handle the PAYMENT transaction (Received amount)
            received_amount = data["received_amount"]
            if received_amount > 0:
                if rn in existing_payments:
                    tx = existing_payments[rn]
                    update_data = {}
                    if tx["ledger_id"] != ledger_id: update_data["ledger_id"] = ledger_id
                    if abs(float(tx.get("amount") or 0) - received_amount) > 0.01:
                        update_data["amount"] = received_amount
                    
                    # Sync metadata for payment too
                    if tx.get("car_number") != data["car_number"]:
                        update_data["car_number"] = data["car_number"]
                        update_data["vehicle_number"] = data["car_number"]
                    
                    # Sync date
                    new_date = data.get("date")
                    if new_date and tx.get("created_at") != new_date:
                        update_data["created_at"] = new_date

                    current_extra = tx.get("extra_fields") or {}
                    new_extra = dict(data["extra_fields"])
                    if data.get("mobile_number"):
                        new_extra["mobile_number"] = data["mobile_number"]

                    if current_extra != new_extra:
                        update_data["extra_fields"] = new_extra

                    if update_data:
                        db.client.table("ledger_transactions").update(update_data).eq("id", tx["id"]).execute()
                else:
                    db.client.table("ledger_transactions").insert({
                        "username": username,
                        "ledger_id": ledger_id,
                        "transaction_type": "PAYMENT",
                        "amount": received_amount,
                        "receipt_number": rn,
                        "is_paid": True,
                        "created_at": data["date"] or now,
                        "notes": f"Auto-sync payment from receipt {rn}",
                        "car_number": data["car_number"],
                        "vehicle_number": data["car_number"],
                        "extra_fields": data["extra_fields"]
                    }).execute()
                
        # 4. Reconcile all balances efficiently
        await reconcile_all_customer_ledger_balances(current_user)

    except Exception as e:
        logger.error(f"Error syncing customer ledgers from invoices: {e}")


@router.get("/dashboard-summary")
async def get_dashboard_summary(current_user: Dict = Depends(get_current_user)):
    """Get the top-level summary for the Udhar dashboard."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Trigger sync from inventory invoices to ensure vendor ledgers are up to date
        await sync_vendor_ledgers_from_invoices(current_user)
        # Trigger sync from verified invoices to ensure customer ledgers are up to date
        await sync_customer_ledgers_from_invoices(current_user)

        # --- Compute total_receivable from actual ledger_transactions (not stale balance_due column) ---
        # This avoids the race condition where /ledgers reconciliation hasn't run yet.
        ledger_resp = db.client.table('customer_ledgers') \
            .select('id, balance_due') \
            .eq('username', username) \
            .execute()
        ledgers = ledger_resp.data or []
        total_receivable = 0.0
        if ledgers:
            ledger_ids = [ld['id'] for ld in ledgers]
            cust_tx_resp = db.client.table('ledger_transactions') \
                .select('ledger_id, amount, transaction_type, is_paid') \
                .eq('username', username) \
                .in_('ledger_id', ledger_ids) \
                .execute()
            expected: Dict[int, float] = {ld['id']: 0.0 for ld in ledgers}
            for tx in (cust_tx_resp.data or []):
                lid = tx.get('ledger_id')
                if lid not in expected:
                    continue
                amt = float(tx.get('amount') or 0)
                ttype = tx.get('transaction_type')
                if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                    expected[lid] += amt
                elif ttype == 'PAYMENT':
                    expected[lid] -= amt
            now_str = datetime.utcnow().isoformat()
            for ld in ledgers:
                lid = ld['id']
                computed = expected[lid]
                stored = float(ld.get('balance_due') or 0)
                if abs(stored - computed) > 0.01:
                    try:
                        db.client.table('customer_ledgers').update({
                            'balance_due': computed,
                            'updated_at': now_str,
                        }).eq('id', lid).execute()
                    except Exception as patch_err:
                        logger.warning(f"Could not patch ledger {lid}: {patch_err}")
                if computed > 0:
                    total_receivable += computed

        total_receivable = round(total_receivable, 2)

        # --- Compute total_payable from actual vendor_ledger_transactions ---
        # This avoids the race condition where /vendor-ledgers reconciliation hasn't run yet.
        v_ledger_resp = db.client.table('vendor_ledgers') \
            .select('id, balance_due') \
            .eq('username', username) \
            .execute()
        v_ledgers = v_ledger_resp.data or []
        total_payable = 0.0
        if v_ledgers:
            v_ledger_ids = [ld['id'] for ld in v_ledgers]
            vend_tx_resp = db.client.table('vendor_ledger_transactions') \
                .select('vendor_ledger_id, amount, transaction_type, is_paid') \
                .eq('username', username) \
                .in_('vendor_ledger_id', v_ledger_ids) \
                .execute()
            v_expected: Dict[int, float] = {ld['id']: 0.0 for ld in v_ledgers}
            for tx in (vend_tx_resp.data or []):
                lid = tx.get('vendor_ledger_id')
                if lid not in v_expected:
                    continue
                amt = float(tx.get('amount') or 0)
                ttype = tx.get('transaction_type')
                if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                    v_expected[lid] += amt
                elif ttype == 'PAYMENT':
                    v_expected[lid] -= amt
            
            if 'now_str' not in locals():
                now_str = datetime.utcnow().isoformat()
                
            for ld in v_ledgers:
                lid = ld['id']
                computed = v_expected[lid]
                stored = float(ld.get('balance_due') or 0)
                if abs(stored - computed) > 0.01:
                    try:
                        db.client.table('vendor_ledgers').update({
                            'balance_due': computed,
                            'updated_at': now_str,
                        }).eq('id', lid).execute()
                    except Exception as patch_err:
                        logger.warning(f"Could not patch vendor ledger {lid}: {patch_err}")
                if computed > 0:
                    total_payable += computed

        total_payable = round(total_payable, 2)

        # Chart Data Aggregation (all time)
        
        # customer transactions (Cash In when PAYMENT)
        # Note: in existing code, PAYMENT to customer decreases balance. means customer gave us (Cash In).
        c_tx_resp = db.client.table('ledger_transactions') \
            .select('amount, created_at') \
            .eq('username', username) \
            .eq('transaction_type', 'PAYMENT') \
            .execute()
            
        # vendor transactions (Cash Out when PAYMENT)
        # Note: in existing code, PAYMENT to vendor decreases balance. means we gave vendor (Cash Out).
        v_tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('amount, created_at') \
            .eq('username', username) \
            .eq('transaction_type', 'PAYMENT') \
            .execute()

        # Group by date
        daily_cashflow = {}
        
        for tx in c_tx_resp.data:
            date_str = tx['created_at'].split('T')[0]
            if date_str not in daily_cashflow:
                daily_cashflow[date_str] = {"cash_in": 0.0, "cash_out": 0.0}
            daily_cashflow[date_str]["cash_in"] += float(tx['amount'])
            
        for tx in v_tx_resp.data:
            date_str = tx['created_at'].split('T')[0]
            if date_str not in daily_cashflow:
                daily_cashflow[date_str] = {"cash_in": 0.0, "cash_out": 0.0}
            daily_cashflow[date_str]["cash_out"] += float(tx['amount'])
            
        # Calculate net and format for chart
        chart_data = []
        for date_str, flow in sorted(daily_cashflow.items()):
            chart_data.append({
                "date": date_str,
                "cash_in": flow["cash_in"],
                "cash_out": flow["cash_out"],
                "net_cashflow": flow["cash_in"] - flow["cash_out"]
            })

        return {
            "status": "success",
            "data": {
                "total_receivable": total_receivable,
                "total_payable": total_payable,
                "chart_data": chart_data
            }
        }
    except Exception as e:
        logger.error(f"Error fetching dashboard summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reconcile-balances")
async def reconcile_all_customer_ledger_balances(current_user: Dict = Depends(get_current_user)):
    """
    Recalculates the balance_due for all customer ledgers based on the sum of their transactions.
    INVOICE adds to the balance.
    PAYMENT subtracts from the balance.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all ledgers
        ledgers_resp = db.client.table("customer_ledgers") \
            .select("id, balance_due") \
            .eq("username", username) \
            .execute()
            
        if not ledgers_resp.data:
            return {"status": "success", "message": "No ledgers found to reconcile", "updated_count": 0}

        # 2. Fetch all transactions
        tx_resp = db.client.table("ledger_transactions") \
            .select("ledger_id, amount, transaction_type, is_paid") \
            .eq("username", username) \
            .execute()

        # 3. Calculate expected balances
        expected_balances = {ld["id"]: 0.0 for ld in ledgers_resp.data}
        
        for tx in (tx_resp.data or []):
            lid = tx["ledger_id"]
            if lid in expected_balances:
                amt = float(tx.get("amount", 0))
                ttype = tx.get("transaction_type")
                if ttype in ["INVOICE", "MANUAL_CREDIT"]:
                    expected_balances[lid] += amt
                elif ttype == "PAYMENT":
                    expected_balances[lid] -= amt

        # 4. Identify drifts and update
        updated_count = 0
        drifts_found = []
        now = datetime.utcnow().isoformat()
        
        for ld in ledgers_resp.data:
            lid = ld["id"]
            ledger_name = ld.get("customer_name", "Unknown")
            current_bal = float(ld.get("balance_due", 0))
            expected_bal = float(expected_balances[lid])
            
            # Use small epsilon for float comparison
            if abs(current_bal - expected_bal) > 0.01:
                logger.info(f"Reconciling ledger {lid} ({ledger_name}): {current_bal} -> {expected_bal}")
                db.client.table("customer_ledgers").update({
                    "balance_due": expected_bal,
                    "updated_at": now
                }).eq("id", lid).execute()
                updated_count += 1
                drifts_found.append({"ledger_id": lid, "customer": ledger_name, "old": current_bal, "new": expected_bal})

        return {
            "status": "success",
            "message": f"Reconciliation complete. Updated {updated_count} ledgers.",
            "updated_count": updated_count,
            "drifts_resolved": drifts_found
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reconciling customer balances: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/manual-entry")
async def create_manual_entry(entry: ManualUdharEntry, current_user: Dict = Depends(get_current_user)):
    """Create a manual Udhar entry for a customer or vendor."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    if entry.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be greater than zero")
        
    if entry.party_type not in ['customer', 'vendor']:
        raise HTTPException(status_code=400, detail="Invalid party_type. Must be 'customer' or 'vendor'")
        
    if entry.entry_type not in ['got', 'gave']:
        raise HTTPException(status_code=400, detail="Invalid entry_type. Must be 'got' or 'gave'")
        
    party_name_clean = entry.party_name.strip()
    if not party_name_clean:
        raise HTTPException(status_code=400, detail="Party name cannot be empty")
        
    db = get_database_client()
    db.set_user_context(username)
    now = datetime.utcnow().isoformat()
    
    try:
        tables = {
            'customer': {
                'ledger_table': 'customer_ledgers',
                'tx_table': 'ledger_transactions',
                'name_field': 'customer_name'
            },
            'vendor': {
                'ledger_table': 'vendor_ledgers',
                'tx_table': 'vendor_ledger_transactions',
                'name_field': 'vendor_name'
            }
        }
        
        cfg = tables[entry.party_type]
        
        # Determine if balance goes up or down
        # Customer: gave -> balance increases (they owe us more). got -> balance decreases (they paid us).
        # Vendor: got -> balance increases (we owe them more). gave -> balance decreases (we paid them).
        is_increase = False
        tx_type = ''
        
        if entry.party_type == 'customer':
            if entry.entry_type == 'gave':
                is_increase = True
                tx_type = 'MANUAL_CREDIT'
            elif entry.entry_type == 'got':
                is_increase = False
                tx_type = 'PAYMENT'
        else: # vendor
            if entry.entry_type == 'got':
                is_increase = True
                tx_type = 'MANUAL_CREDIT'
            elif entry.entry_type == 'gave':
                is_increase = False
                tx_type = 'PAYMENT'
                
        # 1. Upsert Ledger
        ledger_resp = db.client.table(cfg['ledger_table']) \
            .select('*') \
            .eq('username', username) \
            .eq(cfg['name_field'], party_name_clean) \
            .execute()
            
        ledger_data = ledger_resp.data
        if ledger_data:
            ledger = ledger_data[0]
            current_balance = float(ledger.get('balance_due', 0))
            new_balance = current_balance + entry.amount if is_increase else current_balance - entry.amount
            
            update_data = {
                'balance_due': new_balance,
                'updated_at': now
            }
            # Only update last_payment_date if it's a payment (decrease in balance due)
            if not is_increase:
                update_data['last_payment_date'] = now
                
            db.client.table(cfg['ledger_table']).update(update_data).eq('id', ledger['id']).execute()
            ledger_id = ledger['id']
        else:
            new_balance = entry.amount if is_increase else -entry.amount
            new_ledger_resp = db.client.table(cfg['ledger_table']).insert({
                'username': username,
                cfg['name_field']: party_name_clean,
                'balance_due': new_balance,
            }).execute()
            
            if new_ledger_resp.data:
                ledger_id = new_ledger_resp.data[0]['id']
            else:
                raise HTTPException(status_code=500, detail=f"Failed to create ledger for {party_name_clean}")
                
        # 2. Add Transaction
        db.client.table(cfg['tx_table']).insert({
            'username': username,
            'ledger_id': ledger_id,
            'transaction_type': tx_type,
            'amount': entry.amount,
            'notes': entry.notes
        }).execute()
        
        return {
            "status": "success",
            "message": "Manual entry recorded successfully",
            "new_balance": new_balance,
            "ledger_id": ledger_id
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating manual entry: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class TogglePaidStatusRequest(BaseModel):
    is_paid: bool

@router.post("/ledgers/{ledger_id}/transactions/{transaction_id}/toggle-paid")
async def toggle_transaction_paid_status(
    ledger_id: int,
    transaction_id: int,
    request: TogglePaidStatusRequest,
    current_user: Dict = Depends(get_current_user)
):
    """
    Toggle the paid status of a customer invoice transaction.
    When marked as paid, automatically creates a linked PAYMENT transaction.
    When marked as unpaid, deletes the linked PAYMENT transaction.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # 1. Fetch the transaction and verify it belongs to the user and ledger
        tx_resp = db.client.table('ledger_transactions') \
            .select('*') \
            .eq('id', transaction_id) \
            .eq('ledger_id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not tx_resp.data:
            raise HTTPException(status_code=404, detail="Transaction not found")
            
        tx = tx_resp.data[0]
        
        # We only allow toggling paid status on INVOICE transactions for now
        if tx.get('transaction_type') != 'INVOICE':
            raise HTTPException(status_code=400, detail="Only INVOICE transactions can be marked as paid")
            
        current_paid_status = tx.get('is_paid', False)
        
        # If the status is already what's requested, do nothing
        if current_paid_status == request.is_paid:
            return {"status": "success", "message": "Status unchanged"}
            
        # 2. Fetch the ledger to update its balance
        ledger_resp = db.client.table('customer_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Ledger not found")
            
        ledger = ledger_resp.data[0]
        current_balance = float(ledger.get('balance_due', 0))
        tx_amount = float(tx.get('amount', 0))
        now = datetime.utcnow().isoformat()
        
        if request.is_paid:
            # MARKING AS PAID
            # Use actual outstanding due (for receipt-based invoices) to avoid accidental overpayment.
            settlement_amount = tx_amount
            receipt_number = tx.get('receipt_number')
            old_balance_due = 0.0
            old_received = 0.0
            if receipt_number:
                try:
                    invoice_rows_resp = db.client.table('verified_invoices') \
                        .select('balance_due, received_amount') \
                        .eq('username', username) \
                        .eq('receipt_number', receipt_number) \
                        .limit(1) \
                        .execute()

                    if invoice_rows_resp.data:
                        old_balance_due = float(invoice_rows_resp.data[0].get('balance_due', 0) or 0)
                        old_received = float(invoice_rows_resp.data[0].get('received_amount', 0) or 0)
                        if old_balance_due > 0:
                            settlement_amount = old_balance_due
                except Exception as due_err:
                    logger.warning(
                        f"Could not resolve outstanding due for receipt {receipt_number}: {due_err}"
                    )

            # If nothing is due, just mark invoice as paid without creating synthetic payment.
            if settlement_amount <= 0:
                db.client.table('ledger_transactions').update({
                    'is_paid': True,
                    'linked_transaction_id': None
                }).eq('id', transaction_id).execute()

                return {
                    "status": "success",
                    "message": "Successfully marked as paid",
                    "new_balance": current_balance,
                    "is_paid": True
                }

            # Create a PAYMENT transaction for settlement amount
            payment_resp = db.client.table('ledger_transactions').insert({
                'username': username,
                'ledger_id': ledger_id,
                'transaction_type': 'PAYMENT',
                'amount': settlement_amount,
                'notes': f"Auto-generated payment for Invoice {tx.get('receipt_number', '')}",
                'linked_transaction_id': transaction_id # Link it to the invoice
            }).execute()
            
            if not payment_resp.data:
                raise HTTPException(status_code=500, detail="Failed to create payment transaction")
                
            payment_id = payment_resp.data[0]['id']
            
            # Update the invoice transaction
            db.client.table('ledger_transactions').update({
                'is_paid': True,
                'linked_transaction_id': payment_id # Link invoice to the new payment
            }).eq('id', transaction_id).execute()
            
            # Update customer balance (PAYMENT decreases balance due)
            new_balance = current_balance - settlement_amount
            db.client.table('customer_ledgers').update({
                'balance_due': new_balance,
                'last_payment_date': now,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            
            # Sync to verified_invoices
            if receipt_number and settlement_amount > 0:
                try:
                    db.client.table('verified_invoices').update({
                        'balance_due': 0,
                        'received_amount': old_received + old_balance_due,
                        'payment_mode': 'Cash' # or leave as Credit, but it's paid
                    }).eq('username', username).eq('receipt_number', receipt_number).execute()
                except Exception as e:
                    logger.warning(f"Could not update verified_invoices for receipt {receipt_number}: {e}")
            
        else:
            # MARKING AS UNPAID
            linked_payment_id = tx.get('linked_transaction_id')
            linked_payment_amount = 0.0
            
            if linked_payment_id:
                # Read linked payment amount so we can reverse exactly what was applied.
                linked_payment_resp = db.client.table('ledger_transactions') \
                    .select('amount') \
                    .eq('id', linked_payment_id) \
                    .eq('ledger_id', ledger_id) \
                    .eq('username', username) \
                    .eq('transaction_type', 'PAYMENT') \
                    .execute()
                if linked_payment_resp.data:
                    linked_payment_amount = float(linked_payment_resp.data[0].get('amount', 0) or 0)

                # Delete the linked PAYMENT transaction
                db.client.table('ledger_transactions').delete().eq('id', linked_payment_id).execute()
                
            # Update the invoice transaction
            db.client.table('ledger_transactions').update({
                'is_paid': False,
                'linked_transaction_id': None
            }).eq('id', transaction_id).execute()
            
            # Update customer balance (Reverting a PAYMENT increases balance due)
            reverse_amount = linked_payment_amount if linked_payment_amount > 0 else tx_amount
            new_balance = current_balance + reverse_amount
            db.client.table('customer_ledgers').update({
                'balance_due': new_balance,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            
            # Sync revert to verified_invoices
            receipt_number = tx.get('receipt_number')
            if receipt_number:
                try:
                    invoice_rows_resp = db.client.table('verified_invoices') \
                        .select('balance_due, received_amount') \
                        .eq('username', username) \
                        .eq('receipt_number', receipt_number) \
                        .limit(1) \
                        .execute()

                    if invoice_rows_resp.data:
                        old_balance_due = float(invoice_rows_resp.data[0].get('balance_due', 0) or 0)
                        old_received = float(invoice_rows_resp.data[0].get('received_amount', 0) or 0)
                        
                        db.client.table('verified_invoices').update({
                            'balance_due': old_balance_due + reverse_amount,
                            'received_amount': max(0, old_received - reverse_amount),
                            'payment_mode': 'Credit'
                        }).eq('username', username).eq('receipt_number', receipt_number).execute()
                except Exception as e:
                    logger.warning(f"Could not revert verified_invoices for receipt {receipt_number}: {e}")
            
        return {
            "status": "success",
            "message": f"Successfully marked as {'paid' if request.is_paid else 'unpaid'}",
            "new_balance": new_balance,
            "is_paid": request.is_paid
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error toggling transaction paid status: {e}")
        raise HTTPException(status_code=500, detail=str(e))
