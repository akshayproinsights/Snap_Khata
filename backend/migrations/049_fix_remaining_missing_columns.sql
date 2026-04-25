-- ============================================================================
-- MIGRATION 049: Fix Remaining Missing Columns
-- Resolves the remaining 500 errors found in the backend logs
-- ============================================================================

-- Fix for /api/udhar/ledgers/31/transactions
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;

-- Fix for /api/verified/?receipt_number=13401
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Fix for /api/dashboard/inventory-by-priority
ALTER TABLE stock_levels ADD COLUMN IF NOT EXISTS internal_item_name TEXT;

-- Fix for /api/purchase-orders/draft/items
ALTER TABLE draft_purchase_orders ADD COLUMN IF NOT EXISTS added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Fix for /api/dashboard/kpis & /api/dashboard/stock-summary
ALTER TABLE stock_levels ADD COLUMN IF NOT EXISTS current_stock NUMERIC DEFAULT 0;

-- Fix for /api/dashboard/daily-sales-volume
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS type TEXT;

-- Fix for /api/vendor-ledgers/transactions/all
ALTER TABLE inventory_invoices ADD COLUMN IF NOT EXISTS price_hike_amount NUMERIC DEFAULT 0;

-- Fix for /api/udhar/dashboard-summary & syncing customer ledgers
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS customer_details JSONB;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';
