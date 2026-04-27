import os
import sys
import logging

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')

from services.storage import get_storage_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def check_file():
    bucket = "snapkhata-prod"
    key = "omk/sales/20260427_153348_08ea80_CAP2614790005050587755.jpg"
    
    storage = get_storage_client()
    exists = storage.file_exists(bucket, key)
    
    print(f"File exists in bucket '{bucket}' with key '{key}': {exists}")
    
    if not exists:
        print("Checking if it exists in any other folder or prefix...")
        files = storage.list_files(bucket, prefix="omk/sales/20260427_153348")
        print(f"Found files with similar prefix: {files}")

if __name__ == "__main__":
    check_file()
