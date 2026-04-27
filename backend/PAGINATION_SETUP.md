"""
🚀 INTEGRATION GUIDE: Adding Pagination to main.py
This shows how to register the new paginated routes
"""

# In your /root/Snap_Khata/backend/main.py, add this after other route imports:

# ════════════════════════════════════════════════════════════════════════════════
# ADD THESE LINES IN main.py
# ════════════════════════════════════════════════════════════════════════════════

# After line: from routes import upload, inventory, udhar, etc.
# ADD:
# from routes.paginated_api import router as paginated_router

# Then in the app initialization section (after other include_router calls):
# ADD:
# app.include_router(paginated_router, prefix="/api")

# ════════════════════════════════════════════════════════════════════════════════
# COMPLETE EXAMPLE SNIPPET TO ADD
# ════════════════════════════════════════════════════════════════════════════════

"""
# Place this in your main.py after existing imports:

from routes.paginated_api import router as paginated_router

# ... rest of imports ...

# Then in the app setup section (look for where include_router is called):

# Include all routes
app.include_router(upload.router, prefix="/api/upload")
app.include_router(inventory.router, prefix="/api/inventory")
app.include_router(udhar.router, prefix="/api/khata")
app.include_router(dashboard_routes.router, prefix="/api/dashboard")

# ADD THIS NEW LINE:
app.include_router(paginated_router, prefix="/api")

# ... rest of setup ...
"""

# ════════════════════════════════════════════════════════════════════════════════
# DATABASE OPTIMIZATION: RECOMMENDED INDEXES
# ════════════════════════════════════════════════════════════════════════════════

"""
For optimal pagination performance, create these indexes in Supabase:

1. inventory_items table:
   - Index on (username, created_at DESC) - for paginating by date
   - Index on (username, invoice_date DESC) - for sorting by invoice date
   - Index on (username, vendor_name) - for filtering by vendor
   - Index on (username, product_name) - for search queries

2. customer_ledgers table:
   - Index on (username, updated_at DESC) - for recency sorting
   - Index on (username, balance_due DESC) - for balance sorting
   - Index on (username, customer_name) - for lookups

3. ledger_transactions table:
   - Index on (username, customer_name, transaction_date DESC)
   - Index on (username, created_at DESC)

4. upload_tasks table:
   - Index on (username, created_at DESC)
   - Index on (username, status) - for filtering by status

SQL to create indexes:
```sql
-- Inventory indexes
CREATE INDEX idx_inventory_username_created ON inventory_items(username, created_at DESC);
CREATE INDEX idx_inventory_username_invoice_date ON inventory_items(username, invoice_date DESC);
CREATE INDEX idx_inventory_vendor ON inventory_items(username, vendor_name);
CREATE INDEX idx_inventory_product ON inventory_items(username, product_name);

-- Ledger indexes
CREATE INDEX idx_ledger_username_updated ON customer_ledgers(username, updated_at DESC);
CREATE INDEX idx_ledger_balance ON customer_ledgers(username, balance_due DESC);

-- Transaction indexes
CREATE INDEX idx_tx_customer_date ON ledger_transactions(username, customer_name, transaction_date DESC);
CREATE INDEX idx_tx_created ON ledger_transactions(username, created_at DESC);

-- Upload indexes
CREATE INDEX idx_upload_created ON upload_tasks(username, created_at DESC);
CREATE INDEX idx_upload_status ON upload_tasks(username, status);
```

2. Enable Row Level Security (RLS) on all tables to ensure users only see their data
"""
