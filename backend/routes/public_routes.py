from fastapi import APIRouter, HTTPException
from database import get_database_client

router = APIRouter()

@router.get("/receipts/{receipt_number}")
async def get_public_receipt(receipt_number: str):
    """
    Fetch basic public info for a receipt given its receipt_number.
    This endpoint does not require authentication, so anyone with the link can view it.
    """
    try:
        db = get_database_client()
        
        # We need to query the headers to find the matching receipt
        response = db.client.from_("invoice_headers").select("*").eq("receipt_number", receipt_number).maybe_single().execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Receipt not found")
            
        header = response.data
        
        # Try to get the shop name from the user's profile if possible,
        # but since we only have user_id, we can fetch it.
        user_id = header.get("user_id")
        shop_name = "Business Name"
        
        if user_id:
            profile_response = db.client.from_("profiles").select("shop_name").eq("id", user_id).maybe_single().execute()
            if profile_response.data and profile_response.data.get("shop_name"):
                shop_name = profile_response.data.get("shop_name")
        
        is_paid = header.get("verification_status", "").lower() in ["done", "paid", "confirmed"]
        
        return {
            "id": header.get("receipt_number"),
            "image_url": header.get("receipt_link"),
            "customer_name": header.get("customer_name") or header.get("description") or "Customer",
            "total_amount": header.get("amount", 0),
            "paid_amount": header.get("amount", 0) if is_paid else 0,
            "status": "PAID" if is_paid else "PENDING",
            "created_at": header.get("created_at") or header.get("date"),
            "shop_name": shop_name
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching public receipt {receipt_number}: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch receipt data")
