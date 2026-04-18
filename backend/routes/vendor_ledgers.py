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
        last_balance = 0
        for tx_id in request.transaction_ids:
            try:
                last_balance = await _toggle_transaction_paid_status_internal(db, username, tx_id, request.is_paid)
            except HTTPException as e:
                logger.warning(f"Skipping transaction {tx_id}: {e.detail}")
                continue
                
        return {
            "status": "success",
            "message": f"Updated {len(request.transaction_ids)} transactions",
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
        # If we delete an INVOICE, balance decreases (unless it was already PAID, but wait)
        # Actually, if we delete an INVOICE:
        #   - if it was NOT PAID: balance decreases by amount.
        #   - if it was PAID: we should also delete the linked payment. Balance adjustment:
        #     INVOICE (+amount) then PAYMENT (-amount) = 0 net change.
        #     If we delete INVOICE, we should delete the PAYMENT too. Net change still 0.
        # If we delete a PAYMENT:
        #   - balance increases by amount.
        
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
            # If this is a linked payment, we should probably unmark the invoice as paid
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
    """Delete multiple transactions."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        last_balance = 0
        for tx_id in request.transaction_ids:
            try:
                # Reusing the logic from single delete
                # Fetch balance from DB again to avoid race conditions if multiple users are involved, 
                # though here it's fine for simple implementation.
                result = await delete_transaction(tx_id, current_user)
                last_balance = result.get('new_balance', 0)
            except HTTPException as e:
                logger.warning(f"Skipping transaction {tx_id}: {e.detail}")
                continue
                
        return {
            "status": "success",
            "message": f"Deleted {len(request.transaction_ids)} transactions",
            "new_balance": last_balance
        }
    except Exception as e:
        logger.error(f"Error in batch delete transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

