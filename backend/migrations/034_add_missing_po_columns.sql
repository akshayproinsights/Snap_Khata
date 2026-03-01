-- Fix: Add missing columns to purchase_orders and purchase_order_items
-- These columns were added in 031_add_po_tracking_fields.sql but were never
-- applied to production, causing PGRST204 errors when creating POs.

-- Add missing columns to purchase_orders
ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS vendor_invoice_numbers TEXT[],
ADD COLUMN IF NOT EXISTS delivery_date DATE,
ADD COLUMN IF NOT EXISTS completion_percentage NUMERIC DEFAULT 0;

-- Add missing columns to purchase_order_items
ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS received_qty NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS received_date DATE,
ADD COLUMN IF NOT EXISTS vendor_invoice_number TEXT,
ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending';

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_po_completion ON purchase_orders(completion_percentage) WHERE completion_percentage < 100;
CREATE INDEX IF NOT EXISTS idx_po_items_part_number ON purchase_order_items(part_number);
CREATE INDEX IF NOT EXISTS idx_po_items_vendor_invoice ON purchase_order_items(vendor_invoice_number) WHERE vendor_invoice_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_po_items_delivery_status ON purchase_order_items(delivery_status);

-- Reload schema cache so PostgREST picks up the new columns immediately
NOTIFY pgrst, 'reload schema';

SELECT 'Migration 034 complete: purchase_orders.completion_percentage and related columns added.' AS status;
