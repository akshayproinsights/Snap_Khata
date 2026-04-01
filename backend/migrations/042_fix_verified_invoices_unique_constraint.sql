-- ============================================================================
-- CRITICAL SECURITY FIX: Cross-Tenant Data Isolation
-- Migration 042: Fix verified_invoices unique constraint
-- ============================================================================
--
-- BUG: Migration 028 added UNIQUE(row_id) to verified_invoices.
-- row_id values (e.g. '_1', '_2', '_3') are identical across all users.
-- When user Adnak did a Sync & Finish upsert ON CONFLICT(row_id),
-- it overwrote Ak123's rows that share the same row_id — leaking Adnak
-- customer data (e.g. "Jadhav") into Ak123's verified invoices.
--
-- FIX: Replace UNIQUE(row_id) with UNIQUE(username, row_id).
-- ============================================================================

-- Step 1: Drop the incorrect single-column unique constraint
ALTER TABLE verified_invoices DROP CONSTRAINT IF EXISTS verified_invoices_row_id_key;

-- Step 2: Clean up any cross-tenant duplicates that may have been created
-- (keep the row belonging to the correct owner based on most recent creation)
DELETE FROM verified_invoices
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY username, row_id ORDER BY created_at DESC) as r
        FROM verified_invoices
    ) t
    WHERE t.r > 1
);

-- Step 3: Add the correct composite unique constraint
ALTER TABLE verified_invoices
ADD CONSTRAINT verified_invoices_username_row_id_key UNIQUE (username, row_id);

-- Step 4: Add an index to support the new constraint efficiently
CREATE INDEX IF NOT EXISTS idx_verified_invoices_row_id ON verified_invoices(username, row_id);

SELECT 'Migration 042: Cross-tenant isolation fix applied successfully.' AS status;
