import sys
import os

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')

from services.processor import convert_to_dataframe_rows
from unittest.mock import MagicMock

# Mock user_config
user_config = {
    "industry": "automobile"
}

# Mock Gemini response
invoice_data = {
    "header": {
        "receipt_number": "881",
        "date": "05-Nov-2023",
        "customer_name": "John Doe",
        "car_number": "MH04 DN 3413",
        "mobile_number": "9876543210"
    },
    "items": [
        {
            "description": "Engine Oil",
            "quantity": 1,
            "rate": 1470,
            "amount": 1470,
            "confidence": 95
        }
    ],
    "receipt_link": "http://test.com/link"
}

# Mock other requirements for convert_to_dataframe_rows
username = "ARK"

# Call the function
rows = convert_to_dataframe_rows(invoice_data, username)

# Check results
for i, row in enumerate(rows):
    print(f"Row {i} vehicle_number: {row.get('vehicle_number')}")
    print(f"Row {i} customer: {row.get('customer')}")
    print(f"Row {i} extra_fields: {row.get('extra_fields')}")
