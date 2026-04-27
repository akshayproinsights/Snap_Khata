import os
import sys
from typing import Dict, Any

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from services.storage import get_storage_client

def test_resolution():
    storage = get_storage_client()
    
    # Test cases: (bucket, expected_domain_substring)
    test_cases = [
        ("aksh-invoices", "pub-3de23488ca6c4e2392d96de04f8c5cff"),
        ("snapkhata-prod", "pub-1ee455c147c54e23b37edcf721f0e3a9"),
        ("unknown-bucket", "pub-1ee455c147c54e23b37edcf721f0e3a9") # Should fallback to default
    ]
    
    print("Starting Multi-Bucket Resolution Test...")
    print("-" * 50)
    
    success = True
    for bucket, expected in test_cases:
        url = storage.get_public_url(bucket, "test.jpg")
        print(f"Bucket: {bucket:15} -> URL: {url}")
        
        if expected in url:
            print(f"  [PASS] Found expected domain {expected}")
        else:
            print(f"  [FAIL] Expected domain {expected} NOT found in {url}")
            success = False
            
    print("-" * 50)
    if success:
        print("ALL TESTS PASSED!")
    else:
        print("SOME TESTS FAILED!")
        sys.exit(1)

if __name__ == "__main__":
    test_resolution()
