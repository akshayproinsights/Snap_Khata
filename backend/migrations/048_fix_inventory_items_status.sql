-- ============================================================================
-- MIGRATION 048: Fix Inventory Items Status & Missing Columns
-- Fixes blocking 500 error on /api/inventory/items by adding verification_status
-- and ensures compatibility with inventory_processor.py and mobile frontend.
-- ============================================================================

-- 1. Add verification_status (used for filtering pending reviews)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'Pending';

-- 2. Add OCR grouping columns (used by mobile to group line items into bundles)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS invoice_number TEXT;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS vendor_name TEXT;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS invoice_date TEXT;

-- 3. Add quantity and rate (if missing from original schema but used by processor)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS quantity NUMERIC DEFAULT 1;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS rate NUMERIC DEFAULT 0;

-- 4. Add needs_review (boolean flag for math errors)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS needs_review BOOLEAN DEFAULT FALSE;

-- 5. Add discounted_price and taxed_amount (legacy columns used in price hike detection)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS discounted_price NUMERIC DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS taxed_amount NUMERIC DEFAULT 0;

-- 6. Add source_file and receipt_link (linking back to original OCR)
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS source_file TEXT;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS receipt_link TEXT;

-- 7. Add price hike columns
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS previous_rate NUMERIC;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS price_hike_amount NUMERIC;

-- 8. Add foreign key to inventory_invoices
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS inventory_invoice_id BIGINT;

-- Create index for faster pending review lookups
CREATE INDEX IF NOT EXISTS idx_inventory_items_verification_status ON inventory_items(verification_status);
CREATE INDEX IF NOT EXISTS idx_inventory_items_invoice_grouping ON inventory_items(invoice_number, vendor_name, invoice_date);
CREATE INDEX IF NOT EXISTS idx_inventory_items_invoice_id ON inventory_items(inventory_invoice_id);

SELECT 'Migration 048: Inventory items columns fixed successfully!' as status;
