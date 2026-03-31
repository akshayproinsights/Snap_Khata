import json
import glob
import os

files = glob.glob('/root/Snap_Khata/backend/user_configs/templates/*.json')
files.extend(glob.glob('/root/Snap_Khata/backend/user_configs/*.json'))

for fpath in files:
    with open(fpath, 'r') as f:
        data = json.load(f)
    print(f"Modifying {os.path.basename(fpath)}")
    
    revenue_metrics = {
        "enabled": True,
        "data_source": "verified_invoices",
        "date_column": "date",
        "amount_column": "amount",
        "type_column": "type",
        "receipt_column": "receipt_number",
        "filters": {"default_days": 30},
        "search_filters": [
            {"key": "customer_name", "db_column": "customer_name", "label": "Customer Name", "placeholder": "Search customer..."},
            {"key": "part_number", "db_column": "description", "label": "Item", "placeholder": "Search item..."}
        ]
    }
    
    stock_metrics = {
        "enabled": True,
        "data_source": "inventory_items",
        "date_column": "invoice_date",
        "amount_column": "net_bill",
        "stock_column": "qty",
        "receipt_column": "invoice_number",
        "filters": {"default_days": 30}
    }

    if "dashboard_visuals" not in data:
        data["dashboard_visuals"] = {}
        
    if "revenue_metrics" not in data["dashboard_visuals"]:
        data["dashboard_visuals"]["revenue_metrics"] = revenue_metrics
        
    if "stock_metrics" not in data["dashboard_visuals"]:
        data["dashboard_visuals"]["stock_metrics"] = stock_metrics
        
    industry = data.get("industry", "general")
    if industry == "automobile" or "automobile" in os.path.basename(fpath):
        data["dashboard_visuals"]["revenue_metrics"]["search_filters"] = [
            {"key": "customer_name", "db_column": "customer_name", "label": "Customer Name", "placeholder": "Search customer..."},
            {"key": "vehicle_number", "db_column": "car_number", "label": "Vehicle Number", "placeholder": "Search vehicle..."},
            {"key": "part_number", "db_column": "description", "label": "Customer Item", "placeholder": "Search item..."}
        ]
    elif industry == "medical" or "medical" in os.path.basename(fpath):
        data["dashboard_visuals"]["revenue_metrics"]["search_filters"] = [
            {"key": "customer_name", "db_column": "customer_name", "label": "Customer Name", "placeholder": "Search customer..."},
            {"key": "patient_name", "db_column": "patient_name", "label": "Patient Name", "placeholder": "Search patient..."},
            {"key": "doctor_name", "db_column": "doctor_name", "label": "Doctor Name", "placeholder": "Search doctor..."},
            {"key": "part_number", "db_column": "description", "label": "Treatment/Test", "placeholder": "Search treatment..."}
        ]
    else:
        # Default
        data["dashboard_visuals"]["revenue_metrics"]["search_filters"] = [
            {"key": "customer_name", "db_column": "customer_name", "label": "Customer Name", "placeholder": "Search customer..."},
            {"key": "part_number", "db_column": "description", "label": "Item", "placeholder": "Search item..."}
        ]
        
    with open(fpath, 'w') as f:
        json.dump(data, f, indent=4)
        print(f"File {fpath} updated successfully.")
