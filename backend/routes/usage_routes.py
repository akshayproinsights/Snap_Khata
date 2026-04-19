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
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get actual usage statistics for all time periods.
    Returns data in the format expected by the mobile app:
    {
        "1 Week": {"customer_orders": [], "supplier_orders": [], "labels": [], "total_customer": 0, "total_supplier": 0},
        "1 Month": {...},
        "All Time": {...}
    }
    """
    try:
        username = current_user.get("username")
        if not username:
            raise HTTPException(status_code=401, detail="User not authenticated properly")

        db = get_database_client()
        now = datetime.now(timezone.utc)

        # Fetch all usage logs for this user
        response = db.client.table("usage_logs").select("*").eq("username", username).execute()
        logs = response.data

        from collections import defaultdict

        def build_period_data(logs_filtered, period_name):
            """Build data structure for a specific time period."""
            customer_by_date = defaultdict(int)
            supplier_by_date = defaultdict(int)
            total_customer = 0
            total_supplier = 0

            for log in logs_filtered:
                order_type = log.get("order_type")
                try:
                    date_str = log.get("processed_at", "")[:10]  # YYYY-MM-DD
                    if order_type == "customer":
                        total_customer += 1
                        if date_str:
                            customer_by_date[date_str] += 1
                    elif order_type == "supplier":
                        total_supplier += 1
                        if date_str:
                            supplier_by_date[date_str] += 1
                except:
                    pass

            # Sort dates and build chart data
            sorted_dates = sorted(set(customer_by_date.keys()) | set(supplier_by_date.keys()))

            # If no data, return empty structure
            if not sorted_dates:
                return {
                    "customer_orders": [],
                    "supplier_orders": [],
                    "labels": [],
                    "total_customer": 0,
                    "total_supplier": 0
                }

            # Build daily arrays
            customer_orders = [customer_by_date[d] for d in sorted_dates]
            supplier_orders = [supplier_by_date[d] for d in sorted_dates]

            # Format labels based on period
            labels = []
            for d in sorted_dates:
                dt = datetime.strptime(d, "%Y-%m-%d")
                if period_name == "1 Week":
                    labels.append(dt.strftime("%a"))  # Mon, Tue, etc.
                elif period_name == "1 Month":
                    labels.append(dt.strftime("%d"))  # 01, 02, etc.
                else:
                    labels.append(dt.strftime("%b %d"))  # Jan 01

            return {
                "customer_orders": customer_orders,
                "supplier_orders": supplier_orders,
                "labels": labels,
                "total_customer": total_customer,
                "total_supplier": total_supplier
            }

        # Calculate date ranges
        week_ago = now - timedelta(days=7)
        month_ago = now - timedelta(days=30)

        # Filter logs for each period
        week_logs = [log for log in logs if log.get("processed_at", "") >= week_ago.isoformat()]
        month_logs = [log for log in logs if log.get("processed_at", "") >= month_ago.isoformat()]

        return {
            "1 Week": build_period_data(week_logs, "1 Week"),
            "1 Month": build_period_data(month_logs, "1 Month"),
            "All Time": build_period_data(logs, "All Time")
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching usage stats: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to fetch usage stats")
