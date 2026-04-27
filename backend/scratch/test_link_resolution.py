import sys
import os

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')

from routes.inventory import _resolve_receipt_link
from configs import get_r2_config

# Mock environment
os.environ['CLOUDFLARE_R2_PUBLIC_BASE_URL'] = 'https://pub-3de23488ca6c4e2392d96de04f8c5cff.r2.dev'

print(f"Testing with CLOUDFLARE_R2_PUBLIC_BASE_URL: {os.environ['CLOUDFLARE_R2_PUBLIC_BASE_URL']}")

test_links = [
    "r2://adnak-sir-invoices/Akshay_K/purchases/test.jpg",
    "https://pub-1ee455c147c54e23b37edcf721f0e3a9.r2.dev/Akshay_K/purchases/test.jpg",
    "https://pub-3de23488ca6c4e2392d96de04f8c5cff.r2.dev/Akshay_K/purchases/test.jpg",
    "",
    None
]

for link in test_links:
    resolved = _resolve_receipt_link(link)
    print(f"Input: {link}")
    print(f"Output: {resolved}")
    print("-" * 20)
