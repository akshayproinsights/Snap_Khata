-- ============================================================================
-- MIGRATION 033: Add Pipeline Intelligence Columns
-- Smart Procurement Dashboard - Phase 1
-- Date: 2026-02-08
-- ============================================================================

-- 1. Add last_supplier_info to stock_levels for quick vendor lookup
ALTER TABLE stock_levels
ADD COLUMN IF NOT EXISTS last_supplier_info JSONB DEFAULT NULL;
-- Format: {"name": "Bosch", "po_number": "AD20240201001", "last_po_date": "2024-02-01"}

COMMENT ON COLUMN stock_levels.last_supplier_info IS 'Cached vendor info from last PO to avoid joins on dashboard load';

-- 2. Ensure received_qty exists on purchase_order_items (for partial delivery tracking)
ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS received_qty NUMERIC DEFAULT 0;

COMMENT ON COLUMN purchase_order_items.received_qty IS 'Quantity actually received from vendor';

-- 3. Add delivery_status to track line item completion
ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending';
-- Values: 'pending', 'partial', 'complete'

COMMENT ON COLUMN purchase_order_items.delivery_status IS 'Order line status: pending, partial, complete';

-- 4. Create index for efficient pipeline aggregation queries
CREATE INDEX IF NOT EXISTS idx_poi_pipeline 
ON purchase_order_items(username, part_number);

CREATE INDEX IF NOT EXISTS idx_poi_active_orders
ON purchase_order_items(po_id) WHERE delivery_status != 'complete';

-- 5. Create index for stock_levels pipeline queries  
CREATE INDEX IF NOT EXISTS idx_stock_levels_supplier
ON stock_levels(username) WHERE last_supplier_info IS NOT NULL;

-- 6. Verify columns were added
SELECT 
    'stock_levels.last_supplier_info' as column_name,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'stock_levels' AND column_name = 'last_supplier_info'
    ) as exists
UNION ALL
SELECT 
    'purchase_order_items.received_qty',
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' AND column_name = 'received_qty'
    )
UNION ALL
SELECT 
    'purchase_order_items.delivery_status',
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' AND column_name = 'delivery_status'
    );

SELECT 'Migration 033 completed successfully!' as status;
