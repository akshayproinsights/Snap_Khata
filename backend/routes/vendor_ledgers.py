from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime

from auth import get_current_user
from database import get_database_client

logger = logging.getLogger(__name__)

router = APIRouter()

# Schema for Payment
class PaymentCreate(BaseModel):
    amount: float
    notes: Optional[str] = None

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
        # 1. Fetch the transaction
        tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .eq('id', transaction_id) \
            .eq('username', username) \
            .execute()
            
        if not tx_resp.data:
            raise HTTPException(status_code=404, detail="Transaction not found")
            
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
        if request.is_paid and not currently_paid:
            # We are marking it as PAID
            # generate a PAYMENT
            notes = f"Auto-payment for Invoice {transaction.get('invoice_number') or f'#{transaction_id}'}"
            
            payment_resp = db.client.table('vendor_ledger_transactions').insert({
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
            
            # update ledger balance securely
            new_balance = current_balance - amount
            db.client.table('vendor_ledgers').update({
                'balance_due': new_balance,
                'last_payment_date': now,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            
        # 4. Handle Mark as Unpaid
        elif not request.is_paid and currently_paid:
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

