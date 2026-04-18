from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime

from auth import get_current_user
from database import get_database_client

logger = logging.getLogger(__name__)

router = APIRouter()

class PaymentCreate(BaseModel):
    amount: float
    notes: Optional[str] = None

class BatchActionRequest(BaseModel):
    transaction_ids: List[int]
    is_paid: Optional[bool] = None

class VendorLedgerCreate(BaseModel):
    vendor_name: str

@router.post("/vendor-ledgers")
async def create_vendor_ledger(ledger: VendorLedgerCreate, current_user: Dict = Depends(get_current_user)):
    """Create a new vendor ledger."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    vendor_name_clean = ledger.vendor_name.strip()
    if not vendor_name_clean:
         raise HTTPException(status_code=400, detail="Vendor name cannot be empty")
         
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Check if exists
        existing_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('username', username) \
            .eq('vendor_name', vendor_name_clean) \
            .execute()
            
        if existing_resp.data:
            return {
                "status": "success",
                "message": "Vendor Ledger already exists",
                "data": existing_resp.data[0]
            }
            
        new_ledger_resp = db.client.table('vendor_ledgers').insert({
            'username': username,
            'vendor_name': vendor_name_clean,
            'balance_due': 0.0,
        }).execute()
        
        if not new_ledger_resp.data:
            raise HTTPException(status_code=500, detail="Failed to create Vendor Ledger")
            
        return {
            "status": "success",
            "message": "Vendor Ledger created successfully",
            "data": new_ledger_resp.data[0]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating vendor ledger: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/vendor-ledgers")
async def get_vendor_ledgers(current_user: Dict = Depends(get_current_user)):
    """Get all vendor ledgers for the current user."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        response = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('username', username) \
            .order('balance_due', desc=True) \
            .execute()
            
        return {
            "status": "success",
            "data": response.data
        }
    except Exception as e:
        logger.error(f"Error fetching vendor ledgers: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/vendor-ledgers/{ledger_id}/transactions")
async def get_vendor_ledger_transactions(ledger_id: int, current_user: Dict = Depends(get_current_user)):
    """Get transaction history for a specific vendor ledger."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Verify ledger belongs to user
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Vendor Ledger not found")
            
        ledger = ledger_resp.data[0]
        
        # Get transactions
        tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .eq('ledger_id', ledger_id) \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .execute()
            
        return {
            "status": "success",
            "ledger": ledger,
            "data": tx_resp.data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching vendor transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/vendor-ledgers/{ledger_id}")
async def delete_vendor_ledger(ledger_id: int, current_user: Dict = Depends(get_current_user)):
    """Delete a vendor ledger and its transactions."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # Verify ledger belongs to user
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('id') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Vendor Ledger not found")
            
        # Delete the ledger (transactions will be deleted by CASCADE)
        db.client.table('vendor_ledgers').delete().eq('id', ledger_id).execute()
        
        return {
            "status": "success",
            "message": "Vendor Ledger deleted successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting vendor ledger: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/vendor-ledgers/{ledger_id}/pay")
async def record_vendor_payment(ledger_id: int, payment: PaymentCreate, current_user: Dict = Depends(get_current_user)):
    """Record a payment to the vendor, reducing the balance owed."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    if payment.amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be greater than zero")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Vendor Ledger not found")
            
        ledger = ledger_resp.data[0]
        current_balance = float(ledger.get('balance_due', 0))
        
        new_balance = current_balance - payment.amount
        now = datetime.utcnow().isoformat()
        
        db.client.table('vendor_ledgers').update({
            'balance_due': new_balance,
            'last_payment_date': now,
            'updated_at': now
        }).eq('id', ledger_id).execute()
        
        db.client.table('vendor_ledger_transactions').insert({
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
        logger.error(f"Error recording vendor payment: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class TogglePaidRequest(BaseModel):
    is_paid: bool

@router.post("/vendor-ledgers/transactions/{transaction_id}/toggle-paid")
async def toggle_transaction_paid_status(transaction_id: int, request: TogglePaidRequest, current_user: Dict = Depends(get_current_user)):
    """Toggle the paid status of an INVOICE transaction."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        new_balance = await _toggle_transaction_paid_status_internal(db, username, transaction_id, request.is_paid)
        return {
            "status": "success",
            "message": "Paid status updated successfully",
            "new_balance": new_balance
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error toggling paid status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def _toggle_transaction_paid_status_internal(db, username: str, transaction_id: int, is_paid: bool) -> float:
    """Internal helper to toggle paid status and update ledger balance."""
    # 1. Fetch the transaction
    tx_resp = db.client.table('vendor_ledger_transactions') \
        .select('*') \
        .eq('id', transaction_id) \
        .eq('username', username) \
        .execute()
        
    if not tx_resp.data:
        raise HTTPException(status_code=404, detail=f"Transaction {transaction_id} not found")
        
    transaction = tx_resp.data[0]
    if transaction.get('transaction_type') != 'INVOICE':
        raise HTTPException(status_code=400, detail="Only INVOICE transactions can be marked as paid/unpaid")
        
    ledger_id = transaction.get('ledger_id')
    amount = float(transaction.get('amount', 0))
    currently_paid = transaction.get('is_paid', False)
    
    # 2. Fetch the ledger
    ledger_resp = db.client.table('vendor_ledgers') \
        .select('*') \
        .eq('id', ledger_id) \
        .eq('username', username) \
        .execute()
        
    if not ledger_resp.data:
        raise HTTPException(status_code=404, detail="Vendor Ledger not found")
        
    ledger = ledger_resp.data[0]
    current_balance = float(ledger.get('balance_due', 0))
    new_balance = current_balance
    now = datetime.utcnow().isoformat()
    
    # 3. Handle Mark as Paid
    if is_paid and not currently_paid:
        # We are marking it as PAID
        # generate a PAYMENT
        notes = f"Auto-payment for Invoice {transaction.get('invoice_number') or f'#{transaction_id}'}"
        
        db.client.table('vendor_ledger_transactions').insert({
            'username': username,
            'ledger_id': ledger_id,
            'transaction_type': 'PAYMENT',
            'amount': amount,
            'notes': notes,
            'linked_transaction_id': transaction_id
        }).execute()
        
        # update the invoice
        db.client.table('vendor_ledger_transactions').update({
            'is_paid': True
        }).eq('id', transaction_id).execute()
        
        # update ledger balance
        new_balance = current_balance - amount
        db.client.table('vendor_ledgers').update({
            'balance_due': new_balance,
            'last_payment_date': now,
            'updated_at': now
        }).eq('id', ledger_id).execute()
        
    # 4. Handle Mark as Unpaid
    elif not is_paid and currently_paid:
        # We are marking it as UNPAID
        # delete the linked PAYMENT
        db.client.table('vendor_ledger_transactions') \
            .delete() \
            .eq('linked_transaction_id', transaction_id) \
            .eq('username', username) \
            .execute()
            
        # update the invoice
        db.client.table('vendor_ledger_transactions').update({
            'is_paid': False
        }).eq('id', transaction_id).execute()
        
        # update ledger balance
        new_balance = current_balance + amount
        db.client.table('vendor_ledgers').update({
            'balance_due': new_balance,
            'updated_at': now
        }).eq('id', ledger_id).execute()
        
    return new_balance

@router.post("/vendor-ledgers/transactions/batch-toggle-paid")
async def batch_toggle_paid_status(request: BatchActionRequest, current_user: Dict = Depends(get_current_user)):
    """Toggle the paid status of multiple INVOICE transactions."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    if request.is_paid is None:
        raise HTTPException(status_code=400, detail="is_paid field is required")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        tx_ids = request.transaction_ids
        if not tx_ids:
            return {"status": "success", "message": "No transactions to update", "new_balance": 0}

        # ── Bulk fetch all transactions in one query ───────────────────────
        all_tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .in_('id', tx_ids) \
            .eq('username', username) \
            .execute()
        tx_map = {tx['id']: tx for tx in (all_tx_resp.data or [])}

        # Only INVOICE transactions can be toggled
        valid_txs = [tx for tx in tx_map.values() if tx.get('transaction_type') == 'INVOICE']
        if not valid_txs:
            return {"status": "success", "message": "No valid INVOICE transactions found", "new_balance": 0}

        ledger_ids = list({tx['ledger_id'] for tx in valid_txs})

        # ── Bulk fetch all relevant ledgers in one query ───────────────────
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .in_('id', ledger_ids) \
            .eq('username', username) \
            .execute()
        ledger_map = {ld['id']: ld for ld in (ledger_resp.data or [])}

        now = datetime.utcnow().isoformat()
        new_payments_to_insert = []
        tx_ids_to_mark_paid = []
        tx_ids_to_mark_unpaid = []
        linked_tx_ids_to_delete = []
        linked_invoice_ids_to_unmark = []
        balance_deltas = {}  # ledger_id -> delta

        for tx in valid_txs:
            tx_id = tx['id']
            ledger_id = tx['ledger_id']
            amount = float(tx.get('amount', 0))
            currently_paid = tx.get('is_paid', False)


            if request.is_paid and not currently_paid:
                # Mark PAID: create auto-payment, mark invoice paid
                notes = f"Auto-payment for Invoice {tx.get('invoice_number') or f'#{tx_id}'}"
                new_payments_to_insert.append({
                    'username': username,
                    'ledger_id': ledger_id,
                    'transaction_type': 'PAYMENT',
                    'amount': amount,
                    'notes': notes,
                    'linked_transaction_id': tx_id
                })
                tx_ids_to_mark_paid.append(tx_id)
                balance_deltas[ledger_id] = balance_deltas.get(ledger_id, 0) - amount

            elif not request.is_paid and currently_paid:
                # Mark UNPAID: delete linked payment, unmark invoice
                linked_invoice_ids_to_unmark.append(tx_id)
                balance_deltas[ledger_id] = balance_deltas.get(ledger_id, 0) + amount

        # Delete linked PAYMENT records for all being un-paid in one bulk query
        if linked_invoice_ids_to_unmark:
            db.client.table('vendor_ledger_transactions') \
                .delete() \
                .in_('linked_transaction_id', linked_invoice_ids_to_unmark) \
                .eq('username', username) \
                .execute()
            tx_ids_to_mark_unpaid = linked_invoice_ids_to_unmark

        # Batch insert new PAYMENT transactions
        if new_payments_to_insert:
            db.client.table('vendor_ledger_transactions').insert(new_payments_to_insert).execute()

        # Mark invoices as paid (one UPDATE per distinct is_paid value is ideal;
        # Supabase doesn't support batch update with different values, so do 2 calls max)
        if tx_ids_to_mark_paid:
            db.client.table('vendor_ledger_transactions') \
                .update({'is_paid': True}) \
                .in_('id', tx_ids_to_mark_paid) \
                .execute()

        if tx_ids_to_mark_unpaid:
            db.client.table('vendor_ledger_transactions') \
                .update({'is_paid': False}) \
                .in_('id', tx_ids_to_mark_unpaid) \
                .execute()

        # Apply balance deltas — one UPDATE per ledger (not per transaction)
        last_balance = 0
        for ledger_id, delta in balance_deltas.items():
            ledger = ledger_map.get(ledger_id)
            if not ledger:
                continue
            new_balance = float(ledger.get('balance_due', 0)) + delta
            db.client.table('vendor_ledgers').update({
                'balance_due': new_balance,
                'last_payment_date': now if request.is_paid else None,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            last_balance = new_balance

        return {
            "status": "success",
            "message": f"Updated {len(valid_txs)} transactions",
            "new_balance": last_balance
        }
    except Exception as e:
        logger.error(f"Error in batch toggle paid status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/vendor-ledgers/transactions/{transaction_id}")
async def delete_transaction(transaction_id: int, current_user: Dict = Depends(get_current_user)):
    """Delete a single transaction and update ledger balance."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # 1. Fetch the transaction
        tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .eq('id', transaction_id) \
            .eq('username', username) \
            .execute()
            
        if not tx_resp.data:
            raise HTTPException(status_code=404, detail="Transaction not found")
            
        transaction = tx_resp.data[0]
        ledger_id = transaction.get('ledger_id')
        amount = float(transaction.get('amount', 0))
        tx_type = transaction.get('transaction_type')
        is_paid = transaction.get('is_paid', False)
        
        # 2. Fetch the ledger
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Vendor Ledger not found")
            
        ledger = ledger_resp.data[0]
        current_balance = float(ledger.get('balance_due', 0))
        
        # 3. Calculate balance adjustment
        new_balance = current_balance
        if tx_type == 'INVOICE':
            if is_paid:
                # Delete linked payment first
                db.client.table('vendor_ledger_transactions') \
                    .delete() \
                    .eq('linked_transaction_id', transaction_id) \
                    .eq('username', username) \
                    .execute()
                # Net change to balance is 0 because INVOICE + PAYMENT = 0
            else:
                new_balance = current_balance - amount
        elif tx_type == 'PAYMENT':
            new_balance = current_balance + amount
            # If this is a linked payment, unmark the invoice as paid
            linked_id = transaction.get('linked_transaction_id')
            if linked_id:
                db.client.table('vendor_ledger_transactions') \
                    .update({'is_paid': False}) \
                    .eq('id', linked_id) \
                    .eq('username', username) \
                    .execute()

        # 4. Delete the transaction
        db.client.table('vendor_ledger_transactions').delete().eq('id', transaction_id).execute()
        
        # 5. Update ledger balance
        db.client.table('vendor_ledgers').update({
            'balance_due': new_balance,
            'updated_at': datetime.utcnow().isoformat()
        }).eq('id', ledger_id).execute()
        
        return {
            "status": "success",
            "message": "Transaction deleted successfully",
            "new_balance": new_balance
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting transaction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/vendor-ledgers/transactions/batch-delete")
async def batch_delete_transactions(request: BatchActionRequest, current_user: Dict = Depends(get_current_user)):
    """Delete multiple transactions with bulk pre-fetching."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        tx_ids = request.transaction_ids
        if not tx_ids:
            return {"status": "success", "message": "No transactions to delete", "new_balance": 0}

        # ── Bulk fetch all transactions at once ────────────────────────────
        all_tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .in_('id', tx_ids) \
            .eq('username', username) \
            .execute()
        tx_map = {tx['id']: tx for tx in (all_tx_resp.data or [])}

        if not tx_map:
            return {"status": "success", "message": "No transactions found", "new_balance": 0}

        ledger_ids = list({tx['ledger_id'] for tx in tx_map.values()})

        # ── Bulk fetch all relevant ledgers ────────────────────────────────
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .in_('id', ledger_ids) \
            .eq('username', username) \
            .execute()
        ledger_map = {ld['id']: ld for ld in (ledger_resp.data or [])}

        now = datetime.utcnow().isoformat()
        balance_deltas = {}               # ledger_id -> delta
        linked_payment_ids = []           # IDs of auto-payments to delete
        orphaned_invoice_ids = []         # invoice IDs to unmark is_paid

        for tx_id, tx in tx_map.items():
            ledger_id = tx.get('ledger_id')
            amount = float(tx.get('amount', 0))
            tx_type = tx.get('transaction_type')
            is_paid = tx.get('is_paid', False)

            if tx_type == 'INVOICE':
                if is_paid:
                    # Linked payment will also be deleted; net balance change = 0
                    linked_payment_ids.append(tx_id)   # delete payments WHERE linked_transaction_id IN (...)
                else:
                    balance_deltas[ledger_id] = balance_deltas.get(ledger_id, 0) - amount
            elif tx_type == 'PAYMENT':
                balance_deltas[ledger_id] = balance_deltas.get(ledger_id, 0) + amount
                linked_id = tx.get('linked_transaction_id')
                if linked_id:
                    orphaned_invoice_ids.append(linked_id)

        # Delete linked auto-payments for paid invoices
        if linked_payment_ids:
            db.client.table('vendor_ledger_transactions') \
                .delete() \
                .in_('linked_transaction_id', linked_payment_ids) \
                .eq('username', username) \
                .execute()

        # Unmark invoices whose PAYMENT is being deleted
        if orphaned_invoice_ids:
            db.client.table('vendor_ledger_transactions') \
                .update({'is_paid': False}) \
                .in_('id', orphaned_invoice_ids) \
                .eq('username', username) \
                .execute()

        # Bulk delete all requested transactions
        db.client.table('vendor_ledger_transactions') \
            .delete() \
            .in_('id', tx_ids) \
            .eq('username', username) \
            .execute()

        # Apply balance deltas — one UPDATE per affected ledger
        last_balance = 0
        for ledger_id, delta in balance_deltas.items():
            if delta == 0:
                continue
            ledger = ledger_map.get(ledger_id)
            if not ledger:
                continue
            new_balance = float(ledger.get('balance_due', 0)) + delta
            db.client.table('vendor_ledgers').update({
                'balance_due': new_balance,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            last_balance = new_balance

        return {
            "status": "success",
            "message": f"Deleted {len(tx_map)} transactions",
            "new_balance": last_balance
        }
    except Exception as e:
        logger.error(f"Error in batch delete transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))



