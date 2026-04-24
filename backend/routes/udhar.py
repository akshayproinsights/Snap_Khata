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

    OPTIMIZED: Pre-fetches all ledgers and existing transactions in 2 bulk queries
    instead of 2 sequential queries per record, reducing DB round-trips from O(N) to O(1).
    """
    if not final_records:
        return

    db = get_database_client()
    db.set_user_context(username)

    # ── 1. Filter to only Credit records that need processing ─────────────────
    credit_records = []
    for record in final_records:
        payment_mode = record.get('payment_mode', 'Cash')
        balance_due = record.get('balance_due')
        
        raw_name = str(record.get('customer_name') or '').strip()
        raw_details = str(record.get('customer_details') or '').strip()
        
        # Heuristic: if name is empty or generic, prefer details for ledger name
        if not raw_name or raw_name.lower() in ['unknown', 'unknown customer', 'cash customer', '—', '-', 'null']:
            customer_name = raw_details if raw_details else raw_name
        else:
            customer_name = raw_name

        if payment_mode == 'Credit' and customer_name and balance_due is not None:
            try:
                bal = float(balance_due)
            except (TypeError, ValueError):
                continue
            if bal > 0:
                clean_name = str(customer_name).strip()
                logger.info(f"Processing credit for '{clean_name}' (Original: '{raw_name}', Details: '{raw_details}')")
                credit_records.append({
                    **record,
                    '_customer_clean': clean_name,
                    '_balance_due_float': bal,
                })

    if not credit_records:
        logger.info("No Credit records to process for ledgers")
        return

    customer_names = list({r['_customer_clean'] for r in credit_records if r['_customer_clean']})

    # ── 2. Bulk-fetch all relevant ledgers in ONE query ───────────────────────
    ledger_resp = db.client.table('customer_ledgers') \
        .select('id, customer_name, balance_due') \
        .eq('username', username) \
        .in_('customer_name', customer_names) \
        .execute()

    # Map: customer_name -> ledger row
    ledger_map: Dict[str, Dict] = {}
    for row in (ledger_resp.data or []):
        ledger_map[row['customer_name']] = row

    # ── 3. Bulk-fetch all existing INVOICE transactions for ALL ledger IDs ────
    existing_ledger_ids = [row['id'] for row in ledger_map.values()]
    existing_tx_set: set = set()  # (ledger_id, receipt_number)

    if existing_ledger_ids:
        tx_resp = db.client.table('ledger_transactions') \
            .select('ledger_id, receipt_number') \
            .eq('username', username) \
            .eq('transaction_type', 'INVOICE') \
            .in_('ledger_id', existing_ledger_ids) \
            .execute()
        for tx in (tx_resp.data or []):
            if tx.get('receipt_number'):
                existing_tx_set.add((tx['ledger_id'], str(tx['receipt_number'])))

    # ── 4. Process each record entirely in-memory, collect writes ─────────────
    ledger_updates: Dict[str, float] = {}   # ledger_id -> new balance
    new_ledgers: List[Dict] = []            # rows to INSERT into customer_ledgers
    new_transactions: List[Dict] = []       # rows to INSERT into ledger_transactions

    # Track ledgers we are creating mid-loop so siblings share the same pending ledger
    pending_new_ledgers: Dict[str, Dict] = {}  # customer_name -> {balance_due, transactions[]}

    for record in credit_records:
        customer_name_clean = record['_customer_clean']
        balance_due_float = record['_balance_due_float']
        receipt_number = record.get('receipt_number')

        existing_ledger = ledger_map.get(customer_name_clean)

        if existing_ledger:
            ledger_id = existing_ledger['id']
            # Dedup check (in-memory, no DB round-trip)
            if receipt_number and (ledger_id, str(receipt_number)) in existing_tx_set:
                logger.info(f"Transaction for invoice {receipt_number} already exists, skipping duplicate ledger addition")
                continue
                
            if receipt_number:
                existing_tx_set.add((ledger_id, str(receipt_number)))

            # Accumulate balance delta (in case multiple records for same ledger)
            ledger_updates[ledger_id] = ledger_updates.get(ledger_id, float(existing_ledger.get('balance_due', 0))) + balance_due_float

            new_transactions.append({
                'username': username,
                'ledger_id': ledger_id,
                'transaction_type': 'INVOICE',
                'amount': balance_due_float,
                'receipt_number': receipt_number,
                'notes': record.get('customer_details', ''),
            })
        else:
            # No ledger yet — group by customer to avoid duplicate creates for siblings
            if customer_name_clean not in pending_new_ledgers:
                pending_new_ledgers[customer_name_clean] = {
                    'balance_due': 0.0,
                    'transactions': [],
                    'receipts_processed': set()
                }
            
            # Dedup for new ledgers
            if receipt_number:
                if receipt_number in pending_new_ledgers[customer_name_clean]['receipts_processed']:
                    continue
                pending_new_ledgers[customer_name_clean]['receipts_processed'].add(receipt_number)

            pending_new_ledgers[customer_name_clean]['balance_due'] += balance_due_float
            pending_new_ledgers[customer_name_clean]['transactions'].append({
                'receipt_number': receipt_number,
                'amount': balance_due_float,
                'notes': record.get('customer_details', ''),
            })

    # ── 5. Write ledger balance updates (one UPDATE per ledger) ───────────────
    now_iso = datetime.utcnow().isoformat()
    for ledger_id, new_balance in ledger_updates.items():
        try:
            db.client.table('customer_ledgers').update({
                'balance_due': new_balance,
                'updated_at': now_iso,
            }).eq('id', ledger_id).execute()
        except Exception as e:
            logger.error(f"Error updating ledger {ledger_id}: {e}")

    # ── 6. Create new ledgers + their transactions ────────────────────────────
    for customer_name_clean, info in pending_new_ledgers.items():
        try:
            new_ledger_resp = db.client.table('customer_ledgers').insert({
                'username': username,
                'customer_name': customer_name_clean,
                'balance_due': info['balance_due'],
            }).execute()

            if new_ledger_resp.data:
                new_ledger_id = new_ledger_resp.data[0]['id']
                for tx in info['transactions']:
                    new_transactions.append({
                        'username': username,
                        'ledger_id': new_ledger_id,
                        'transaction_type': 'INVOICE',
                        **tx,
                    })
            else:
                logger.error(f"Failed to create ledger for {customer_name_clean}")
        except Exception as e:
            logger.error(f"Error creating ledger for {customer_name_clean}: {e}")

    # ── 7. Batch-insert all new transactions in ONE query ─────────────────────
    if new_transactions:
        try:
            db.client.table('ledger_transactions').insert(new_transactions).execute()
            logger.info(f"✅ Inserted {len(new_transactions)} ledger transactions in batch")
        except Exception as e:
            logger.error(f"Error batch-inserting ledger transactions: {e}")

@router.get("/ledgers")
async def get_customer_ledgers(current_user: Dict = Depends(get_current_user)):
    """Get all customer ledgers for the current user."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        response = db.client.table('customer_ledgers') \
            .select('*') \
            .eq('username', username) \
            .order('balance_due', desc=True) \
            .execute()
            
        return {
            "status": "success",
            "data": response.data
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
            vi_resp = db.client.table('verified_invoices').select('receipt_number, amount, received_amount, balance_due').in_('receipt_number', receipt_numbers).eq('username', username).execute()
            
            for vi in vi_resp.data:
                rn = vi.get('receipt_number')
                if not rn:
                    continue
                if rn not in enrichment:
                    enrichment[rn] = {'amount_sum': 0.0, 'received_amount': 0.0, 'balance_due': 0.0}
                enrichment[rn]['amount_sum'] += float(vi.get('amount', 0) or 0)
                enrichment[rn]['received_amount'] = float(vi.get('received_amount', 0) or 0)
                enrichment[rn]['balance_due'] = float(vi.get('balance_due', 0) or 0)
                
        for i, tx in enumerate(transactions):
            if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number') in enrichment:
                enr = enrichment[tx['receipt_number']]
                grand_total = enr['received_amount'] + enr['balance_due']
                
                # Update the INVOICE amount to grand_total for display purposes
                # We copy it so we don't mutate shared references unexpectedly
                enriched_tx = dict(tx)
                if grand_total > 0:
                    enriched_tx['amount'] = grand_total 
                enriched_transactions.append(enriched_tx)
                
                # If there was an initial payment, construct a dummy PAYMENT transaction
                if enr['received_amount'] > 0:
                    dummy_payment = {
                        # Use a predictable negative ID bounded by loop index to avoid React/Flutter key collisions
                        'id': -(tx['id'] * 1000 + i), 
                        'ledger_id': ledger_id,
                        'transaction_type': 'PAYMENT',
                        'amount': enr['received_amount'],
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
        # (they share the same created_at as their parent invoice, but sort ensures stable display)
        enriched_transactions.sort(key=lambda x: x['created_at'], reverse=True)
            
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
    """Get all customer transactions for the current user across all ledgers."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Fetch transactions with customer_name from joined ledger table
        response = db.client.table('ledger_transactions') \
            .select('*, customer_ledgers(customer_name)') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(limit) \
            .execute()
            
        return {
            "status": "success",
            "data": response.data
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
    Scans all Credit verified_invoices with balance_due > 0 and ensures
    a matching customer_ledger + INVOICE transaction exists.
    """
    username = current_user.get("username")
    if not username:
        return

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all Credit invoices with outstanding balance
        invoices_resp = db.client.table("verified_invoices") \
            .select("id, receipt_number, customer_name, customer_details, balance_due, verification_date") \
            .eq("username", username) \
            .eq("payment_mode", "Credit") \
            .gt("balance_due", 0) \
            .execute()

        invoices = invoices_resp.data or []
        if not invoices:
            return

        receipt_numbers = [inv["receipt_number"] for inv in invoices if inv.get("receipt_number")]

        # 2. Fetch existing INVOICE transactions
        existing_tx_resp = db.client.table("ledger_transactions") \
            .select("receipt_number") \
            .eq("username", username) \
            .eq("transaction_type", "INVOICE") \
            .in_("receipt_number", receipt_numbers) \
            .execute()

        already_synced = {tx["receipt_number"] for tx in (existing_tx_resp.data or []) if tx.get("receipt_number")}

        # 3. Only process invoices not yet fully synced, deduplicated by receipt number
        unique_missing = {}
        for inv in invoices:
            rn = inv.get("receipt_number")
            if rn and rn not in already_synced:
                # Store the invoice, ensuring we only process one entry per receipt_number
                if rn not in unique_missing:
                    unique_missing[rn] = inv
        
        missing_invoices = list(unique_missing.values())

        if not missing_invoices:
            return

        # 4. Fetch existing customer ledgers
        ledgers_resp = db.client.table("customer_ledgers") \
            .select("id, customer_name, balance_due") \
            .eq("username", username) \
            .execute()

        ledger_map: Dict[str, Dict] = {}
        for row in (ledgers_resp.data or []):
            ledger_map[str(row["customer_name"]).strip().lower()] = row

        now = datetime.utcnow().isoformat()
        
        for inv in missing_invoices:
            raw_name = str(inv.get("customer_name") or "").strip()
            raw_details = str(inv.get("customer_details") or "").strip()
            
            if not raw_name or raw_name.lower() in ['unknown', 'unknown customer', 'cash customer', '—', '-', 'null']:
                customer_name_raw = raw_details if raw_details else raw_name
            else:
                customer_name_raw = raw_name

            if not customer_name_raw:
                continue

            customer_key = customer_name_raw.lower()
            balance_due = float(inv.get("balance_due") or 0)

            if customer_key in ledger_map:
                ledger = ledger_map[customer_key]
                ledger_id = ledger["id"]
                new_balance = float(ledger.get("balance_due") or 0) + balance_due
                db.client.table("customer_ledgers").update({
                    "balance_due": new_balance,
                    "updated_at": now,
                }).eq("id", ledger_id).execute()
                ledger_map[customer_key]["balance_due"] = new_balance
            else:
                new_ledger_resp = db.client.table("customer_ledgers").insert({
                    "username": username,
                    "customer_name": customer_name_raw,
                    "balance_due": balance_due,
                }).execute()

                if not new_ledger_resp.data:
                    continue

                ledger_id = new_ledger_resp.data[0]["id"]
                ledger_map[customer_key] = {
                    "id": ledger_id,
                    "customer_name": customer_name_raw,
                    "balance_due": balance_due,
                }

            db.client.table("ledger_transactions").insert({
                "username": username,
                "ledger_id": ledger_id,
                "transaction_type": "INVOICE",
                "amount": balance_due,
                "receipt_number": inv["receipt_number"],
                "is_paid": False,
                "created_at": inv.get("verification_date") or now,
                "notes": raw_details,
            }).execute()

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

        # Calculate Total Receivable (customer ledgers balance > 0)
        receivable_resp = db.client.table('customer_ledgers') \
            .select('balance_due') \
            .eq('username', username) \
            .gt('balance_due', 0) \
            .execute()
        total_receivable = sum(item['balance_due'] for item in receivable_resp.data) if receivable_resp.data else 0.0

        # Calculate Total Payable (vendor ledgers balance > 0)
        payable_resp = db.client.table('vendor_ledgers') \
            .select('balance_due') \
            .eq('username', username) \
            .gt('balance_due', 0) \
            .execute()
        total_payable = sum(item['balance_due'] for item in payable_resp.data) if payable_resp.data else 0.0

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
            .select("ledger_id, amount, transaction_type") \
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
            current_bal = float(ld.get("balance_due", 0))
            expected_bal = float(expected_balances[lid])
            
            # Use small epsilon for float comparison
            if abs(current_bal - expected_bal) > 0.01:
                db.client.table("customer_ledgers").update({
                    "balance_due": expected_bal,
                    "updated_at": now
                }).eq("id", lid).execute()
                updated_count += 1
                drifts_found.append({"ledger_id": lid, "old": current_bal, "new": expected_bal})

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
