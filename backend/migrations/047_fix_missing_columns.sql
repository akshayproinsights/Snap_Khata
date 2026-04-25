-- ============================================================================
-- MIGRATION 047: Fix Missing Columns
-- Fixes two blocking 500 errors:
--   1. upload_tasks.task_type missing -> crashes /api/upload/recent-task
--   2. verified_invoices.customer_name missing -> crashes /api/udhar/dashboard-summary
-- ============================================================================

-- 1. Add task_type to upload_tasks (distinguishes 'sales' vs 'inventory' uploads)
ALTER TABLE upload_tasks ADD COLUMN IF NOT EXISTS task_type TEXT DEFAULT 'sales';
CREATE INDEX IF NOT EXISTS idx_upload_tasks_task_type ON upload_tasks(task_type);

-- 2. Add customer_name to verified_invoices
--    (was missing from the original schema; needed for udhar ledger sync)
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS customer_name TEXT;

SELECT 'Migration 047: Missing columns added successfully!' as status;
