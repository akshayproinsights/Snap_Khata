from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from datetime import datetime

from auth import get_current_user
from database import get_database_client
from services.storage import get_storage_client

logger = logging.getLogger(__name__)

router = APIRouter()

def _resolve_receipt_link(receipt_link: str) -> str:
    """
    Convert internal r2://bucket/key URLs to proper HTTPS public URLs.
    If the URL is already a valid HTTP/HTTPS URL it is returned unchanged.
    """
    if not receipt_link or not receipt_link.startswith('r2://'):
        return receipt_link or ""
    try:
        path = receipt_link[5:]  # strip 'r2://'
        parts = path.split('/', 1)
        if len(parts) != 2:
            logger.warning(f"Cannot parse r2:// URL '{receipt_link}' — returning as-is")
            return receipt_link
        bucket, key = parts[0], parts[1]
        storage = get_storage_client()
        public_url = storage.get_public_url(bucket, key)
        if public_url:
            return public_url
    except Exception as e:
        logger.error(f"Error resolving receipt link {receipt_link}: {e}")
    return receipt_link

class PaymentCreate(BaseModel):
    amount: float
    notes: Optional[str] = None

class BatchActionRequest(BaseModel):
    transaction_ids: List[int]
    is_paid: Optional[bool] = None

class VendorLedgerCreate(BaseModel):
    vendor_name: str

class OnboardInvoicePaidRequest(BaseModel):
    vendor_name: str
    invoice_number: str
    amount: float
    date: Optional[str] = None

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
            
        # Enrich INVOICE transactions with actual invoice data
        invoice_numbers = [tx['invoice_number'] for tx in tx_resp.data if tx.get('transaction_type') == 'INVOICE' and tx.get('invoice_number')]
        
        enriched_data = []
        if invoice_numbers:
            # Fetch inventory invoices for these invoice numbers
            invoices_resp = db.client.table('inventory_invoices') \
                .select('*') \
                .eq('username', username) \
                .in_('invoice_number', invoice_numbers) \
                .execute()
            
            invoice_map = {inv['invoice_number']: inv for inv in (invoices_resp.data or [])}
            
            for tx in tx_resp.data:
                enriched_tx = tx.copy()
                if tx.get('transaction_type') == 'INVOICE' and tx.get('invoice_number'):
                    inv = invoice_map.get(tx['invoice_number'])
                    if inv:
                        # Extract amounts (Inventory Invoices use total_amount, amount_paid, balance_owed)
                        total_amount = float(inv.get('total_amount') or 0)
                        received_amount = float(inv.get('amount_paid') or 0)
                        balance_owed = float(inv.get('balance_owed') or 0)
                        
                        # Add raw data for UI
                        enriched_tx['raw_invoice_data'] = inv
                        
                        # For history, show the full amount and received amount
                        enriched_tx['grand_total'] = total_amount
                        enriched_tx['received_amount'] = received_amount
                        
                        # Update display amount to grand_total if it's currently 0 or balance
                        # This matches udhar.py behavior
                        if total_amount > 0:
                            enriched_tx['amount'] = total_amount
                        
                        # Add receipt link to top level
                        enriched_tx['receipt_link'] = inv.get('receipt_link') or ''
                
                enriched_data.append(enriched_tx)
        else:
            enriched_data = tx_resp.data or []
            
        return {
            "status": "success",
            "ledger": ledger,
            "data": enriched_data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching vendor transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/transactions/all")
async def get_all_vendor_transactions(limit: int = 50, current_user: Dict = Depends(get_current_user)):
    """Get all vendor transactions for the current user across all ledgers.
    
    Enriches each INVOICE transaction with `total_price_hike` — the sum of
    price_hike_amount from inventory_invoices rows matching that invoice number,
    so the mobile app can display a 'Price hike detected' alert.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # 1. Fetch latest ledger transactions (Credit invoices and Payments)
        response = db.client.table('vendor_ledger_transactions') \
            .select('*, vendor_ledgers(vendor_name, balance_due)') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(limit) \
            .execute()
        
        ledger_txs_raw = response.data or []
        
        # Group ledger transactions by invoice_number to avoid duplicates in feed
        grouped_ledger_txs: Dict[str, Dict] = {}
        unified_txs = []
        
        for tx in ledger_txs_raw:
            inv_num = tx.get('invoice_number')
            tx_type = tx.get('transaction_type')
            
            if tx_type == 'INVOICE' and inv_num:
                if inv_num not in grouped_ledger_txs:
                    grouped_ledger_txs[inv_num] = tx
                    unified_txs.append(tx)
                else:
                    # Merge amounts if multiple entries exist for same invoice
                    grouped_ledger_txs[inv_num]['amount'] = float(grouped_ledger_txs[inv_num].get('amount') or 0) + float(tx.get('amount') or 0)
            else:
                # Payments or unnumbered invoices go straight in
                unified_txs.append(tx)

        # Track invoice numbers we already have from the ledger
        ledger_invoice_numbers = {
            tx['invoice_number']
            for tx in unified_txs
            if tx.get('transaction_type') == 'INVOICE' and tx.get('invoice_number')
        }

        # 2. Fetch latest inventory invoices (for Cash or un-ledgered invoices)
        inv_resp = db.client.table('inventory_invoices') \
            .select('*') \
            .eq('username', username) \
            .order('created_at', desc=True) \
            .limit(limit) \
            .execute()
        
        for inv in (inv_resp.data or []):
            inv_num = inv.get('invoice_number')
            if inv_num and inv_num not in ledger_invoice_numbers:
                unified_txs.append({
                    'id': inv.get('id', 0),
                    'ledger_id': None,
                    'username': username,
                    'transaction_type': 'INVOICE',
                    'amount': inv.get('total_amount') or 0.0,
                    'invoice_number': inv_num,
                    'created_at': inv.get('created_at'),
                    'is_paid': True,
                    'vendor_ledgers': {
                        'vendor_name': inv.get('vendor_name') or ''
                    },
                    'invoice_date': inv.get('invoice_date'),
                    'receipt_link': _resolve_receipt_link(inv.get('receipt_link')),
                    'is_verified': True,
                    'balance_owed': inv.get('balance_owed', 0.0),
                    'payment_mode': inv.get('payment_mode', 'Cash')
                })
                ledger_invoice_numbers.add(inv_num)

        # 3. Collect ALL unique invoice numbers to fetch items for
        all_invoice_numbers = list(ledger_invoice_numbers)

        # Build a map: invoice_number -> total_price_hike from inventory_invoices
        price_hike_map: Dict[str, float] = {}
        if all_invoice_numbers:
            try:
                hike_resp = db.client.table('inventory_invoices') \
                    .select('invoice_number, price_hike_amount') \
                    .eq('username', username) \
                    .in_('invoice_number', all_invoice_numbers) \
                    .execute()

                for row in (hike_resp.data or []):
                    inv_num = row.get('invoice_number')
                    hike = float(row.get('price_hike_amount') or 0)
                    if inv_num:
                        price_hike_map[inv_num] = price_hike_map.get(inv_num, 0.0) + hike
            except Exception as hike_err:
                logger.warning(f"Could not fetch price_hike_amount: {hike_err}")

        # 4. Fetch inventory items to enrich transactions
        item_meta: Dict[str, Dict] = {}
        try:
            # Also look for recent items that might not have an invoice record yet
            items_rns_resp = db.client.table('inventory_items') \
                .select('invoice_number') \
                .eq('username', username) \
                .order('created_at', desc=True) \
                .limit(limit * 2) \
                .execute()
            
            item_rns = {row['invoice_number'] for row in (items_rns_resp.data or []) if row.get('invoice_number')}
            search_rns = list(set(all_invoice_numbers) | item_rns)
            
            if search_rns:
                items_resp = db.client.table('inventory_items') \
                    .select('id, invoice_number, invoice_date, vendor_name, receipt_link, payment_mode, balance_owed, verification_status, net_bill, description, quantity, rate, amount_mismatch, part_number, created_at, price_hike_amount, previous_rate') \
                    .eq('username', username) \
                    .in_('invoice_number', search_rns) \
                    .execute()

                for row in (items_resp.data or []):
                    inv_num = row.get('invoice_number')
                    if inv_num:
                        if inv_num not in item_meta:
                            item_meta[inv_num] = {
                                'invoice_date': row.get('invoice_date') or '',
                                'vendor_name': row.get('vendor_name') or '',
                                'receipt_link': _resolve_receipt_link(row.get('receipt_link')),
                                'payment_mode': row.get('payment_mode') or 'Credit',
                                'balance_owed': float(row.get('balance_owed') or 0),
                                'is_verified': row.get('verification_status') == 'Done',
                                'items': [],
                            }
                        item_meta[inv_num]['items'].append({
                            'id': row.get('id'),
                            'invoice_number': inv_num,
                            'description': row.get('description') or '',
                            'quantity': row.get('quantity') or 0, 
                            'rate': row.get('rate') or 0,
                            'net_bill': float(row.get('net_bill') or 0),
                            'amount_mismatch': float(row.get('amount_mismatch') or 0),
                            'part_number': row.get('part_number') or '',
                            'verification_status': row.get('verification_status') or '',
                            'receipt_link': row.get('receipt_link') or '',
                            'invoice_date': row.get('invoice_date') or '',
                            'vendor_name': row.get('vendor_name') or '',
                            'payment_mode': row.get('payment_mode') or 'Credit',
                            'created_at': row.get('created_at') or '',
                            'price_hike_amount': float(row.get('price_hike_amount') or 0.0),
                            'previous_rate': float(row.get('previous_rate') or 0.0),
                        })
        except Exception as items_err:
            logger.warning(f"Could not enrich vendor transactions with inventory_items: {items_err}")

        # 5. Add Fragmented Items (not in ledger or inventory_invoices)
        for inv_num, meta in item_meta.items():
            # ONLY add if verified. Pending items should not appear in activity feed
            if inv_num not in ledger_invoice_numbers and meta.get('is_verified'):
                items = meta['items']
                total_amount = sum(float(i.get('net_bill') or 0.0) for i in items)
                earliest_ts = min([i.get('created_at') for i in items if i.get('created_at')] or [datetime.utcnow().isoformat()])
                
                unified_txs.append({
                    'id': items[0].get('id', 0),
                    'ledger_id': None,
                    'username': username,
                    'transaction_type': 'INVOICE',
                    'amount': total_amount,
                    'invoice_number': inv_num,
                    'created_at': earliest_ts,
                    'is_paid': meta.get('payment_mode') == 'Cash' or meta.get('balance_owed', 1.0) == 0.0,
                    'vendor_ledgers': {
                        'vendor_name': meta.get('vendor_name') or ''
                    },
                    'invoice_date': meta.get('invoice_date'),
                    'receipt_link': meta.get('receipt_link'),
                    'is_verified': meta.get('is_verified', False),
                    'balance_owed': meta.get('balance_owed', 0.0),
                    'inventory_items': items,
                    'payment_mode': meta.get('payment_mode', 'Cash')
                })

        # 6. Final Enrichment of Unified Transactions
        for tx in unified_txs:
            inv_num = tx.get('invoice_number')
            tx['total_price_hike'] = price_hike_map.get(inv_num, 0.0) if inv_num else 0.0

            if tx.get('transaction_type') == 'INVOICE' and inv_num and inv_num in item_meta:
                if not tx.get('inventory_items'):
                    meta = item_meta[inv_num]
                    tx['invoice_date'] = meta.get('invoice_date') or tx.get('invoice_date') or ''
                    tx['receipt_link'] = _resolve_receipt_link(meta.get('receipt_link') or tx.get('receipt_link') or '')
                    tx['vendor_name_enriched'] = meta.get('vendor_name') or ''
                    tx['payment_mode'] = meta.get('payment_mode') or tx.get('payment_mode') or 'Credit'
                    tx['balance_owed'] = meta.get('balance_owed') or tx.get('balance_owed') or 0.0
                    tx['is_verified'] = True # If it's in the ledger, it's verified
                    tx['inventory_items'] = meta.get('items', [])
            else:
                tx.setdefault('invoice_date', '')
                tx.setdefault('receipt_link', '')
                tx.setdefault('inventory_items', [])

        # Sort combined list by created_at descending
        unified_txs.sort(key=lambda x: x.get('created_at') or '', reverse=True)

        return {
            "status": "success",
            "data": unified_txs[:limit]
        }

    except Exception as e:
        logger.error(f"Error fetching all vendor transactions: {e}")
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

@router.post("/vendor-ledgers/onboard-invoice-paid")
async def onboard_invoice_paid(request: OnboardInvoicePaidRequest, current_user: Dict = Depends(get_current_user)):
    """Onboard an inventory invoice into the ledger and mark it as paid."""
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")
        
    db = get_database_client()
    db.set_user_context(username)
    
    try:
        # 1. Get or create ledger
        ledger_resp = db.client.table('vendor_ledgers') \
            .select('*') \
            .eq('username', username) \
            .eq('vendor_name', request.vendor_name) \
            .execute()
            
        if ledger_resp.data:
            ledger = ledger_resp.data[0]
            ledger_id = ledger['id']
        else:
            # Create ledger
            new_ledger_resp = db.client.table('vendor_ledgers').insert({
                'username': username,
                'vendor_name': request.vendor_name,
                'balance_due': 0.0,
            }).execute()
            if not new_ledger_resp.data:
                raise HTTPException(status_code=500, detail="Failed to create Vendor Ledger")
            ledger = new_ledger_resp.data[0]
            ledger_id = ledger['id']

        # 2. Check if transaction exists
        tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('*') \
            .eq('username', username) \
            .eq('ledger_id', ledger_id) \
            .eq('invoice_number', request.invoice_number) \
            .eq('transaction_type', 'INVOICE') \
            .execute()
            
        if tx_resp.data:
            transaction = tx_resp.data[0]
            transaction_id = transaction['id']
            if transaction.get('is_paid'):
                return {
                    "status": "success",
                    "message": "Invoice already onboarded and paid",
                    "transaction_id": transaction_id
                }
        else:
            # Create transaction
            # Balance-due is usually increased by INVOICE, but if we mark it paid immediately, 
            # net change is 0. However, _toggle_paid_status_internal handles balance updates.
            # So first create invoice (which increases balance), then toggle paid (which decreases it).
            
            # Update balance for the new invoice
            current_balance = float(ledger.get('balance_due', 0))
            new_balance_with_invoice = current_balance + request.amount
            
            db.client.table('vendor_ledgers').update({
                'balance_due': new_balance_with_invoice,
                'updated_at': datetime.utcnow().isoformat()
            }).eq('id', ledger_id).execute()

            insert_tx_resp = db.client.table('vendor_ledger_transactions').insert({
                'username': username,
                'ledger_id': ledger_id,
                'transaction_type': 'INVOICE',
                'amount': request.amount,
                'invoice_number': request.invoice_number,
                'is_paid': False,
                'created_at': request.date or datetime.utcnow().isoformat()
            }).execute()
            
            if not insert_tx_resp.data:
                raise HTTPException(status_code=500, detail="Failed to create transaction")
            
            transaction = insert_tx_resp.data[0]
            transaction_id = transaction['id']

        # 3. Mark as paid
        final_balance = await _toggle_transaction_paid_status_internal(db, username, transaction_id, True)
        
        # 4. Handle initial sync to inventory_invoices (marking it as paid)
        invoice_num = request.invoice_number
        vendor_name = request.vendor_name
        if invoice_num and vendor_name:
            try:
                db.client.table('inventory_invoices') \
                    .update({'payment_mode': 'Cash', 'balance_owed': 0}) \
                    .eq('username', username) \
                    .eq('vendor_name', vendor_name) \
                    .eq('invoice_number', invoice_num) \
                    .execute()
            except Exception as sync_err:
                logger.warning(f"Failed to sync payment_mode in onboard_invoice_paid: {sync_err}")

        return {
            "status": "success",
            "message": "Invoice onboarded and marked as paid",
            "transaction_id": transaction_id,
            "new_balance": final_balance
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error onboarding invoice paid: {e}")
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

    # ─── SYNC TO INVENTORY INVOICES ───────────────────────────────────────────
    # If this transaction has an invoice number, we should sync the payment_mode
    # back to inventory_invoices so the inventory dashboard is reactive.
    invoice_num = transaction.get('invoice_number')
    vendor_name = ledger.get('vendor_name')
    if invoice_num and vendor_name:
        mode = 'Cash' if is_paid else 'Credit'
        bal = 0 if is_paid else amount
        try:
            db.client.table('inventory_invoices') \
                .update({'payment_mode': mode, 'balance_owed': bal}) \
                .eq('username', username) \
                .eq('vendor_name', vendor_name) \
                .eq('invoice_number', invoice_num) \
                .execute()
        except Exception as sync_err:
            logger.warning(f"Failed to sync payment_mode to inventory_invoices: {sync_err}")
    # ──────────────────────────────────────────────────────────────────────────
        
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

        # 4. Prevent "resurrection" by updating the source inventory_invoices
        if tx_type == 'INVOICE':
            invoice_num = transaction.get('invoice_number')
            vendor_name = ledger.get('vendor_name')
            if invoice_num and vendor_name:
                db.client.table('inventory_invoices') \
                    .update({'payment_mode': 'Cash', 'balance_owed': 0}) \
                    .eq('username', username) \
                    .eq('vendor_name', vendor_name) \
                    .eq('invoice_number', invoice_num) \
                    .execute()

        # 5. Delete the transaction
        db.client.table('vendor_ledger_transactions').delete().eq('id', transaction_id).execute()
        
        # 6. Update ledger balance
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

        # Prevent "resurrection" by updating the source inventory_invoices for all deleted INVOICE transactions
        for tx_id, tx in tx_map.items():
            if tx.get('transaction_type') == 'INVOICE':
                invoice_num = tx.get('invoice_number')
                ledger_id = tx.get('ledger_id')
                vendor_name = ledger_map.get(ledger_id, {}).get('vendor_name')
                if invoice_num and vendor_name:
                    try:
                        db.client.table('inventory_invoices') \
                            .update({'payment_mode': 'Cash', 'balance_owed': 0}) \
                            .eq('username', username) \
                            .eq('vendor_name', vendor_name) \
                            .eq('invoice_number', invoice_num) \
                            .execute()
                    except Exception as e:
                        logger.error(f"Failed to update inventory_invoice for {vendor_name} {invoice_num}: {e}")

        # Apply balance deltas — one UPDATE per affected ledger
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




@router.post("/vendor-ledgers/sync-from-invoices")
async def sync_vendor_ledgers_from_invoices(current_user: Dict = Depends(get_current_user)):
    """
    Reconcile vendor_ledgers against inventory_invoices.
    Scans all Credit inventory_invoices with balance_owed > 0 and ensures
    a matching vendor_ledger + INVOICE transaction exists.
    Already-synced invoices are skipped (idempotent).
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all invoices to ensure all vendors are onboarded to ledgers
        invoices_resp = db.client.table("inventory_invoices") \
            .select("id, invoice_number, vendor_name, balance_owed, invoice_date, payment_mode") \
            .eq("username", username) \
            .execute()

        invoices = invoices_resp.data or []
        if not invoices:
            return {
                "status": "success",
                "message": "No Credit invoices found to sync",
                "ledgers_created": 0,
                "transactions_created": 0,
            }

        invoice_numbers = [inv["invoice_number"] for inv in invoices if inv.get("invoice_number")]

        # 2. Fetch existing INVOICE transactions for these invoice numbers
        existing_tx_resp = db.client.table("vendor_ledger_transactions") \
            .select("invoice_number") \
            .eq("username", username) \
            .eq("transaction_type", "INVOICE") \
            .in_("invoice_number", invoice_numbers) \
            .execute()

        already_synced = {tx["invoice_number"] for tx in (existing_tx_resp.data or [])}

        # 3. Only process invoices not yet fully synced, SUMMING items for the same invoice number
        unique_missing = {}
        for inv in invoices:
            inv_num = inv.get("invoice_number")
            if inv_num and inv_num not in already_synced:
                if inv_num not in unique_missing:
                    # Initialize with a copy to avoid modifying original
                    unique_missing[inv_num] = dict(inv)
                    unique_missing[inv_num]["balance_owed"] = float(inv.get("balance_owed") or 0)
                else:
                    # Balance owed is consistent across multi-line invoices, no need to sum
                    pass
        
        missing_invoices = list(unique_missing.values())

        if not missing_invoices:
            return {
                "status": "success",
                "message": "All Credit invoices already synced",
                "ledgers_created": 0,
                "transactions_created": 0,
            }

        # 4. Fetch existing vendor ledgers for this user
        ledgers_resp = db.client.table("vendor_ledgers") \
            .select("id, vendor_name, balance_due") \
            .eq("username", username) \
            .execute()

        ledger_map: Dict[str, Dict] = {}
        for row in (ledgers_resp.data or []):
            ledger_map[str(row["vendor_name"]).strip().lower()] = row

        now = datetime.utcnow().isoformat()
        ledgers_created = 0
        transactions_created = 0

        for inv in missing_invoices:
            vendor_name_raw = str(inv.get("vendor_name") or "").strip()
            if not vendor_name_raw:
                logger.warning(f"Skipping invoice {inv.get('invoice_number')} - no vendor name")
                continue

            vendor_key = vendor_name_raw.lower()
            balance_owed = float(inv.get("balance_owed") or 0)

            if vendor_key in ledger_map:
                ledger = ledger_map[vendor_key]
                ledger_id = ledger["id"]
                new_balance = float(ledger.get("balance_due") or 0) + balance_owed
                db.client.table("vendor_ledgers").update({
                    "balance_due": new_balance,
                    "updated_at": now,
                }).eq("id", ledger_id).execute()
                ledger_map[vendor_key]["balance_due"] = new_balance
            else:
                new_ledger_resp = db.client.table("vendor_ledgers").insert({
                    "username": username,
                    "vendor_name": vendor_name_raw,
                    "balance_due": balance_owed,
                }).execute()

                if not new_ledger_resp.data:
                    logger.error(f"Failed to create ledger for {vendor_name_raw}")
                    continue

                ledger_id = new_ledger_resp.data[0]["id"]
                ledger_map[vendor_key] = {
                    "id": ledger_id,
                    "vendor_name": vendor_name_raw,
                    "balance_due": balance_owed,
                }
                ledgers_created += 1

            # Record transaction
            db.client.table("vendor_ledger_transactions").insert({
                "username": username,
                "ledger_id": ledger_id,
                "transaction_type": "INVOICE",
                "amount": balance_owed,
                "invoice_number": inv["invoice_number"],
                "is_paid": (inv.get("payment_mode") != "Credit" or balance_owed == 0),
                "created_at": inv.get("invoice_date") or now,
            }).execute()
            transactions_created += 1

        logger.info(
            f"Sync complete for {username}: "
            f"{ledgers_created} ledgers created, {transactions_created} transactions created"
        )

        return {
            "status": "success",
            "message": (
                f"Sync complete: {ledgers_created} new ledger(s), "
                f"{transactions_created} transaction(s) backfilled"
            ),
            "ledgers_created": ledgers_created,
            "transactions_created": transactions_created,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error syncing vendor ledgers from invoices: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/vendor-ledgers/reconcile-balances")
async def reconcile_all_ledger_balances(current_user: Dict = Depends(get_current_user)):
    """
    Recalculates the balance_due for all vendor ledgers based on the sum of their transactions.
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
        ledgers_resp = db.client.table("vendor_ledgers") \
            .select("id, balance_due") \
            .eq("username", username) \
            .execute()
            
        if not ledgers_resp.data:
            return {"status": "success", "message": "No ledgers found to reconcile", "updated_count": 0}

        # 2. Fetch all transactions
        tx_resp = db.client.table("vendor_ledger_transactions") \
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
                if ttype == "INVOICE":
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
                db.client.table("vendor_ledgers").update({
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
        logger.error(f"Error reconciling balances: {e}")
        raise HTTPException(status_code=500, detail=str(e))

