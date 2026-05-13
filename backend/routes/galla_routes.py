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
            
        return {"status": "success", "data": resp.data or []}
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
