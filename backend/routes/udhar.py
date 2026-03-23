from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime, timedelta

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
                # 1. Add Transaction
                # Check if this invoice receipt_number already caused a transaction
                receipt_number = record.get('receipt_number')
                ledger_id = None
                
                # Fetch existing ledger first to get its ID (we need ID to check for existing transactions)
                ledger_resp = db.client.table('customer_ledgers') \
                    .select('id, balance_due') \
                    .eq('username', username) \
                    .eq('customer_name', customer_name_clean) \
                    .execute()
                
                existing_ledger = ledger_resp.data[0] if ledger_resp.data else None

                if receipt_number and existing_ledger:
                    ledger_id = existing_ledger['id']
                    existing_tx = db.client.table('ledger_transactions') \
                        .select('id') \
                        .eq('ledger_id', ledger_id) \
                        .eq('receipt_number', receipt_number) \
                        .eq('transaction_type', 'INVOICE') \
                        .execute()
                    
                    # Prevent duplicate ledger increment if transaction already exists
                    if existing_tx.data:
                        logger.info(f"Transaction for invoice {receipt_number} already exists, skipping duplicate ledger addition")
                        continue

                # 2. Upsert Ledger
                if existing_ledger:
                    # Update existing ledger
                    ledger_id = existing_ledger['id']
                    new_balance = float(existing_ledger.get('balance_due', 0)) + balance_due_float
                    db.client.table('customer_ledgers').update({
                        'balance_due': new_balance,
                        'updated_at': datetime.utcnow().isoformat()
                    }).eq('id', ledger_id).execute()
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
                
                # 3. Add Transaction Record
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
            .select('id') \
            .eq('id', ledger_id) \
            .eq('username', username) \
            .execute()
            
        if not ledger_resp.data:
            raise HTTPException(status_code=404, detail="Ledger not found")
            
        # Delete the ledger (transactions will be deleted by CASCADE)
        db.client.table('customer_ledgers').delete().eq('id', ledger_id).execute()
        
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

@router.get("/dashboard-summary")
async def get_dashboard_summary(current_user: Dict = Depends(get_current_user)):
    """Get the top-level summary for the Udhar dashboard."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
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
            # MARING AS PAID
            # Create a PAYMENT transaction
            payment_resp = db.client.table('ledger_transactions').insert({
                'username': username,
                'ledger_id': ledger_id,
                'transaction_type': 'PAYMENT',
                'amount': tx_amount,
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
            new_balance = current_balance - tx_amount
            db.client.table('customer_ledgers').update({
                'balance_due': new_balance,
                'last_payment_date': now,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            
        else:
            # MARKING AS UNPAID
            linked_payment_id = tx.get('linked_transaction_id')
            
            if linked_payment_id:
                # Delete the linked PAYMENT transaction
                db.client.table('ledger_transactions').delete().eq('id', linked_payment_id).execute()
                
            # Update the invoice transaction
            db.client.table('ledger_transactions').update({
                'is_paid': False,
                'linked_transaction_id': None
            }).eq('id', transaction_id).execute()
            
            # Update customer balance (Reverting a PAYMENT increases balance due)
            new_balance = current_balance + tx_amount
            db.client.table('customer_ledgers').update({
                'balance_due': new_balance,
                'updated_at': now
            }).eq('id', ledger_id).execute()
            
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
