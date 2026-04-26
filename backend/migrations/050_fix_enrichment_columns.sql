-- ============================================================================
-- MIGRATION 050: Fix Missing Enrichment and Dashboard Columns
-- Resolves errors in /api/udhar/transactions/all and /api/vendor-ledgers/transactions/all
-- ============================================================================

-- Fix for verified_invoices (Udhar enrichment)
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS receipt_link TEXT;
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Credit';
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS mobile_number BIGINT;

-- Fix for inventory_items (Vendor Ledger enrichment)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Credit';
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS balance_owed NUMERIC DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS net_bill NUMERIC DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS amount_mismatch NUMERIC DEFAULT 0;

-- Fix for stock_levels (Dashboard summaries)
ALTER TABLE stock_levels ADD COLUMN IF NOT EXISTS total_value NUMERIC DEFAULT 0;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';
