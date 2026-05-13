from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any, List
from pydantic import BaseModel
from database import get_database_client
from auth import get_current_user
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

class GallaTransactionCreate(BaseModel):
    transaction_type: str  # CASH_SALE, MONEY_IN, MONEY_OUT
    amount: float
    notes: str = ""

@router.get("/balance")
async def get_galla_balance(current_user: Dict = Depends(get_current_user)):
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        resp = db.client.table("galla_transactions") \
            .select("amount, transaction_type") \
            .eq("username", username) \
            .execute()
            
        balance = 0.0
        for tx in (resp.data or []):
            amt = float(tx.get("amount", 0))
            if tx.get("transaction_type") in ("CASH_SALE", "MONEY_IN"):
                balance += amt
            elif tx.get("transaction_type") == "MONEY_OUT":
                balance -= amt
                
        return {"status": "success", "data": {"balance": round(balance, 2)}}
    except Exception as e:
        logger.error(f"Error fetching Galla balance: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/transactions")
async def get_galla_transactions(current_user: Dict = Depends(get_current_user)):
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        resp = db.client.table("galla_transactions") \
            .select("*") \
            .eq("username", username) \
            .order("created_at", desc=True) \
            .execute()
            
        transactions = resp.data or []
        
        # Enrich with verified_invoices
        receipt_numbers = {tx['receipt_number'] for tx in transactions if tx.get('receipt_number')}
        
        invoice_items_map = {}
        invoice_meta = {}
        if receipt_numbers:
            try:
                vi_resp = db.client.table('verified_invoices') \
                    .select('*') \
                    .eq('username', username) \
                    .in_('receipt_number', list(receipt_numbers)) \
                    .execute()
                for vi in (vi_resp.data or []):
                    rn = vi.get('receipt_number')
                    if rn:
                        if rn not in invoice_items_map:
                            invoice_items_map[rn] = []
                        invoice_items_map[rn].append(vi)
                        
                        if rn not in invoice_meta:
                            invoice_meta[rn] = vi
                        else:
                            if vi.get('id', 0) > invoice_meta[rn].get('id', 0):
                                invoice_meta[rn] = vi
            except Exception as e:
                logger.warning(f"Error fetching verified_invoices for galla: {e}")
                
        for tx in transactions:
            rn = tx.get('receipt_number')
            if rn and rn in invoice_meta:
                meta = invoice_meta[rn]
                items = invoice_items_map.get(rn, [])
                
                tx['receipt_link'] = meta.get('receipt_link') or ''
                tx['invoice_date'] = meta.get('date') or ''
                tx['upload_date'] = meta.get('upload_date') or ''
                tx['customer_name'] = meta.get('customer_name') or ''
                tx['mobile_number'] = str(meta.get('mobile_number') or '')
                tx['payment_mode'] = meta.get('payment_mode') or 'Cash'
                tx['type'] = meta.get('type') or 'Cash'
                tx['received_amount'] = meta.get('received_amount') or tx.get('amount')
                tx['balance_due'] = meta.get('balance_due') or 0
                tx['items'] = items

        return {"status": "success", "data": transactions}
    except Exception as e:
        logger.error(f"Error fetching Galla transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/transaction")
async def create_galla_transaction(
    tx_data: GallaTransactionCreate,
    current_user: Dict = Depends(get_current_user)
):
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    if tx_data.transaction_type not in ("CASH_SALE", "MONEY_IN", "MONEY_OUT"):
        raise HTTPException(status_code=400, detail="Invalid transaction type")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        insert_data = {
            "username": username,
            "transaction_type": tx_data.transaction_type,
            "amount": tx_data.amount,
            "notes": tx_data.notes
        }
        resp = db.client.table("galla_transactions").insert(insert_data).execute()
        return {"status": "success", "data": resp.data[0] if resp.data else None}
    except Exception as e:
        logger.error(f"Error creating Galla transaction: {e}")
        raise HTTPException(status_code=500, detail=str(e))
