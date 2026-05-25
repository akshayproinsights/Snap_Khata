"""Item Catalogue endpoints — CRUD operations for user_item_catalogue"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import logging

import auth
from database import get_database_client

logger = logging.getLogger(__name__)

router = APIRouter()


class CatalogueItemResponse(BaseModel):
    id: int
    username: str
    item_name: str
    last_price: float
    unit: str
    use_count: int
    last_used_at: Optional[str] = None
    created_at: Optional[str] = None


class AddItemRequest(BaseModel):
    item_name: str
    last_price: float = 0.0
    unit: str = "NOS"


class EditItemRequest(BaseModel):
    item_name: Optional[str] = None
    last_price: Optional[float] = None
    unit: Optional[str] = None


@router.get("", response_model=List[CatalogueItemResponse])
async def get_catalogue(current_user: Dict[str, Any] = Depends(auth.get_current_user)):
    """
    Return all items in the logged-in user's catalogue, sorted by use_count DESC
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        db = get_database_client()
        resp = (
            db.client.table("user_item_catalogue")
            .select("*")
            .eq("username", username)
            .order("use_count", desc=True)
            .order("id", desc=True)
            .execute()
        )
        items = []
        for row in (resp.data or []):
            # Parse numeric price safely
            price = 0.0
            if row.get("last_price") is not None:
                try:
                    price = float(row.get("last_price"))
                except (ValueError, TypeError):
                    price = 0.0
            
            items.append(
                CatalogueItemResponse(
                    id=row.get("id"),
                    username=row.get("username"),
                    item_name=row.get("item_name"),
                    last_price=price,
                    unit=row.get("unit") or "NOS",
                    use_count=row.get("use_count") or 0,
                    last_used_at=row.get("last_used_at"),
                    created_at=row.get("created_at"),
                )
            )
        return items
    except Exception as e:
        logger.error(f"Error fetching catalogue for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch item catalogue")


@router.post("", response_model=CatalogueItemResponse)
async def add_catalogue_item(
    body: AddItemRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
):
    """
    Manually add a new item to the user's catalogue
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    if not body.item_name or not body.item_name.strip():
        raise HTTPException(status_code=400, detail="Item name is required")

    item_name_cleaned = body.item_name.strip()

    try:
        db = get_database_client()
        
        # Check if item already exists
        check_resp = (
            db.client.table("user_item_catalogue")
            .select("*")
            .eq("username", username)
            .eq("item_name", item_name_cleaned)
            .execute()
        )
        
        if check_resp.data:
            # Item already exists, we will update its price and unit, but preserve use_count or increment it
            existing = check_resp.data[0]
            resp = (
                db.client.table("user_item_catalogue")
                .update({
                    "last_price": body.last_price,
                    "unit": body.unit,
                })
                .eq("id", existing["id"])
                .execute()
            )
        else:
            # Create new
            resp = (
                db.client.table("user_item_catalogue")
                .insert({
                    "username": username,
                    "item_name": item_name_cleaned,
                    "last_price": body.last_price,
                    "unit": body.unit,
                    "use_count": 1,
                })
                .execute()
            )
        
        if not resp.data:
            raise HTTPException(status_code=500, detail="Failed to save item to catalogue")
            
        row = resp.data[0]
        return CatalogueItemResponse(
            id=row.get("id"),
            username=row.get("username"),
            item_name=row.get("item_name"),
            last_price=float(row.get("last_price") or 0.0),
            unit=row.get("unit") or "NOS",
            use_count=row.get("use_count") or 1,
            last_used_at=row.get("last_used_at"),
            created_at=row.get("created_at"),
        )
    except Exception as e:
        logger.error(f"Error adding catalogue item for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to add catalogue item")


@router.put("/{item_id}", response_model=CatalogueItemResponse)
async def update_catalogue_item(
    item_id: int,
    body: EditItemRequest,
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
):
    """
    Update item name, price, or unit in the catalogue
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        db = get_database_client()
        
        # Verify ownership
        check_resp = (
            db.client.table("user_item_catalogue")
            .select("*")
            .eq("username", username)
            .eq("id", item_id)
            .execute()
        )
        if not check_resp.data:
            raise HTTPException(status_code=404, detail="Item not found in your catalogue")
            
        update_data = {}
        if body.item_name is not None:
            if not body.item_name.strip():
                raise HTTPException(status_code=400, detail="Item name cannot be empty")
            update_data["item_name"] = body.item_name.strip()
        if body.last_price is not None:
            update_data["last_price"] = body.last_price
        if body.unit is not None:
            update_data["unit"] = body.unit

        if not update_data:
            # Nothing to update, return current
            row = check_resp.data[0]
        else:
            resp = (
                db.client.table("user_item_catalogue")
                .update(update_data)
                .eq("id", item_id)
                .eq("username", username)  # defence-in-depth: enforce ownership at query level
                .execute()
            )
            if not resp.data:
                raise HTTPException(status_code=500, detail="Failed to update item")
            row = resp.data[0]
            
        return CatalogueItemResponse(
            id=row.get("id"),
            username=row.get("username"),
            item_name=row.get("item_name"),
            last_price=float(row.get("last_price") or 0.0),
            unit=row.get("unit") or "NOS",
            use_count=row.get("use_count") or 0,
            last_used_at=row.get("last_used_at"),
            created_at=row.get("created_at"),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating catalogue item {item_id} for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to update catalogue item")


@router.delete("/{item_id}")
async def delete_catalogue_item(
    item_id: int,
    current_user: Dict[str, Any] = Depends(auth.get_current_user),
):
    """
    Remove an item from the user's catalogue
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        db = get_database_client()
        
        # Verify ownership
        check_resp = (
            db.client.table("user_item_catalogue")
            .select("*")
            .eq("username", username)
            .eq("id", item_id)
            .execute()
        )
        if not check_resp.data:
            raise HTTPException(status_code=404, detail="Item not found in your catalogue")
            
        db.client.table("user_item_catalogue").delete().eq("id", item_id).eq("username", username).execute()  # defence-in-depth: enforce ownership at query level
        return {"success": True, "message": "Item deleted from catalogue"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting catalogue item {item_id} for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete catalogue item")


@router.post("/sync")
async def sync_catalogue_from_bills(
    current_user: Dict[str, Any] = Depends(auth.get_current_user)
):
    """
    Analyze verified_invoices for this user and build the catalogue.
    Preserves existing catalogue prices for duplicate items, only updating use_count.
    Adds new items found in bills.
    """
    username = current_user.get("username", "")
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        db = get_database_client()
        
        # Fetch verified invoices
        # Select description, rate, upload_date/date
        vi_resp = (
            db.client.table("verified_invoices")
            .select("description, rate, date, upload_date")
            .eq("username", username)
            .execute()
        )
        
        records = vi_resp.data or []
        if not records:
            return {"success": True, "synced_count": 0, "message": "No bills found to sync"}

        # Group by description in python
        item_data = {}  # name -> {last_price, use_count, date}
        for r in records:
            name = r.get("description")
            if not name or not name.strip():
                continue
            name = name.strip()
            
            rate = r.get("rate")
            try:
                rate_val = float(rate) if rate is not None else 0.0
            except (ValueError, TypeError):
                rate_val = 0.0
                
            upload_date = r.get("upload_date") or r.get("date") or ""
            
            if name not in item_data:
                item_data[name] = {
                    "last_price": rate_val,
                    "use_count": 0,
                    "date": upload_date
                }
            
            item_data[name]["use_count"] += 1
            if upload_date and upload_date > item_data[name]["date"]:
                item_data[name]["last_price"] = rate_val
                item_data[name]["date"] = upload_date

        # Fetch existing catalogue items to preserve their prices
        existing_resp = (
            db.client.table("user_item_catalogue")
            .select("item_name, last_price, unit, use_count")
            .eq("username", username)
            .execute()
        )
        existing_items = {row["item_name"]: row for row in (existing_resp.data or [])}

        upsert_records = []
        for name, info in item_data.items():
            if name in existing_items:
                # Keep the manually configured/existing price and unit, sum or update use_count
                upsert_records.append({
                    "username": username,
                    "item_name": name,
                    "last_price": float(existing_items[name]["last_price"] or 0.0),
                    "unit": existing_items[name]["unit"] or "NOS",
                    "use_count": max(info["use_count"], existing_items[name]["use_count"] or 1),
                })
            else:
                # Insert as new
                upsert_records.append({
                    "username": username,
                    "item_name": name,
                    "last_price": info["last_price"],
                    "unit": "NOS",
                    "use_count": info["use_count"],
                })

        if upsert_records:
            # Batch upsert
            db.client.table("user_item_catalogue").upsert(upsert_records, on_conflict="username,item_name").execute()

        logger.info(f"Synced {len(upsert_records)} catalogue items from bills for {username}")
        return {
            "success": True,
            "synced_count": len(upsert_records),
            "message": f"Successfully synced {len(upsert_records)} items from your bills"
        }
    except Exception as e:
        logger.error(f"Error syncing catalogue for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to sync catalogue from bills")
