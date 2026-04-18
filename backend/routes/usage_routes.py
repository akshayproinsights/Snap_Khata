from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any
import logging
from auth import get_current_user
from database import get_database_client
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("/stats")
async def get_usage_stats(
    filter: str = Query("All Time", description="Filter for stats: '1 Week', '1 Month', 'All Time'"),
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get actual usage statistics based on records processed via sync-finish.
    """
    try:
        username = current_user.get("username")
        if not username:
            raise HTTPException(status_code=401, detail="User not authenticated properly")
            
        db = get_database_client()
        
        # Build the time filter
        now = datetime.now(timezone.utc)
        start_date = None
        
        if filter == "1 Week":
            start_date = now - timedelta(days=7)
        elif filter == "1 Month":
            start_date = now - timedelta(days=30)
            
        # Instead of grouping by day, we just need total counts grouped by order_type
        # for a simple replacement of the frontend mock data
        query = db.client.table("usage_logs").select("*").eq("username", username)
        
        if start_date:
            query = query.gte("processed_at", start_date.isoformat())
            
        response = query.execute()
        logs = response.data
        
        # Aggregate the data
        customer_orders = 0
        supplier_orders = 0
        
        # For the line chart, the frontend expects a list of daily values
        # e.g., [{"day": "Mon", "value": 10}, ...]
        # We can group counts by date
        from collections import defaultdict
        
        customer_by_date = defaultdict(int)
        supplier_by_date = defaultdict(int)
        
        for log in logs:
            if log.get("order_type") == "customer":
                customer_orders += 1
                try:
                    date_str = log.get("processed_at", "")[:10]  # YYYY-MM-DD
                    if date_str:
                        customer_by_date[date_str] += 1
                except: pass
            elif log.get("order_type") == "supplier":
                supplier_orders += 1
                try:
                    date_str = log.get("processed_at", "")[:10]  # YYYY-MM-DD
                    if date_str:
                        supplier_by_date[date_str] += 1
                except: pass

        # Sort dates and format for chart points
        # Keep it simple: if just total counts are enough, we can send that,
        # but the chart needs data points.
        def format_chart_data(date_counts):
            sorted_dates = sorted(date_counts.keys())
            chart_data = []
            for d in sorted_dates:
                # Convert YYYY-MM-DD to a short string like "DD MMM"
                # Since we don't have a complex date formatter here, just use the string
                chart_data.append({"date": d, "value": date_counts[d]})
            
            # If no data, provide an empty base point so the chart doesn't crash
            if not chart_data:
                chart_data.append({"date": now.strftime("%Y-%m-%d"), "value": 0})
            return chart_data
            
        return {
            "totalCustomerOrders": customer_orders,
            "totalSupplierOrders": supplier_orders,
            "customerChartData": format_chart_data(customer_by_date),
            "supplierChartData": format_chart_data(supplier_by_date)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching usage stats: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to fetch usage stats")
