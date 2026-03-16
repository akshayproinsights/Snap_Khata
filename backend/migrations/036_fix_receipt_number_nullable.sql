-- ============================================================================
-- Migration 036: Make legacy columns nullable in inventory_mapped
-- Date: 2026-03-06
-- Purpose: The new customer-item mapping flow (endpoints under
--          /api/inventory-mapping/customer-items/*) inserts records without
--          the legacy receipt_number, row_id, or part_number columns.
--          These must be nullable for the new flow to work.
-- ============================================================================

-- Make receipt_number nullable (was NOT NULL in original schema)
ALTER TABLE inventory_mapped ALTER COLUMN receipt_number DROP NOT NULL;

-- Make row_id nullable
ALTER TABLE inventory_mapped ALTER COLUMN row_id DROP NOT NULL;

-- Make part_number nullable
ALTER TABLE inventory_mapped ALTER COLUMN part_number DROP NOT NULL;

-- Make quantity nullable (was NOT NULL DEFAULT 1)
ALTER TABLE inventory_mapped ALTER COLUMN quantity DROP NOT NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

SELECT 'Migration 036 completed: inventory_mapped legacy columns are now nullable.' AS status;
