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

async def process_ledgers_for_verified_invoices(username: str, final_records: List[Dict[str, Any]]):
    """
    Called from verification.py during Sync & Finish.
    Checks for credit records and updates customer ledgers and creates transactions.
    """
    if not final_records:
        return
        
    db = get_database_client()
    db.set_user_context(username)
    
    for record in final_records:
        payment_mode = record.get('payment_mode', 'Cash')
        balance_due = record.get('balance_due')
        # Try customer_name first (from verified_invoices), fallback to customer_details (from verification_dates)
        customer_name = record.get('customer_name') or record.get('customer_details')
        
        # We only care about Credit transactions that have a customer name and a balance due
        if payment_mode == 'Credit' and customer_name and balance_due is not None and float(balance_due) > 0:
            customer_name_clean = str(customer_name).strip()
            if not customer_name_clean:
                continue
                
            balance_due_float = float(balance_due)
                
            try:
                # 1. Upsert Ledger
                # Fetch existing ledger
                ledger_resp = db.client.table('customer_ledgers') \
                    .select('*') \
                    .eq('username', username) \
                    .eq('customer_name', customer_name_clean) \
                    .execute()
                    
                ledger_data = ledger_resp.data
                
                if ledger_data:
                    # Update existing ledger
                    ledger = ledger_data[0]
                    new_balance = float(ledger.get('balance_due', 0)) + balance_due_float
                    db.client.table('customer_ledgers').update({
                        'balance_due': new_balance,
                        'updated_at': datetime.utcnow().isoformat()
                    }).eq('id', ledger['id']).execute()
                    ledger_id = ledger['id']
                else:
                    # Create new ledger
                    new_ledger_resp = db.client.table('customer_ledgers').insert({
                        'username': username,
                        'customer_name': customer_name_clean,
                        'balance_due': balance_due_float,
                    }).execute()
                    
                    if new_ledger_resp.data:
                        ledger_id = new_ledger_resp.data[0]['id']
                    else:
                        logger.error(f"Failed to create ledger for {customer_name_clean}")
                        continue
                
                # 2. Add Transaction
                # Check if this invoice receipt_number already caused a transaction
                receipt_number = record.get('receipt_number')
                if receipt_number:
                    existing_tx = db.client.table('ledger_transactions') \
                        .select('id') \
                        .eq('ledger_id', ledger_id) \
                        .eq('receipt_number', receipt_number) \
                        .eq('transaction_type', 'INVOICE') \
                        .execute()
                    
                    # Prevent duplicate ledger increment on consecutive syncs of same invoice
                    if existing_tx.data:
                        logger.info(f"Transaction for invoice {receipt_number} already exists, skipping duplicate ledger addition")
                        continue
                        
                db.client.table('ledger_transactions').insert({
                    'username': username,
                    'ledger_id': ledger_id,
                    'transaction_type': 'INVOICE',
                    'amount': balance_due_float,
                    'receipt_number': receipt_number,
                    'notes': record.get('customer_details', '')
                }).execute()
            except Exception as e:
                logger.error(f"Error processing ledger for {customer_name_clean}: {e}")

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
            
        return {
            "status": "success",
            "ledger": ledger,
            "data": tx_resp.data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching transactions: {e}")
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
