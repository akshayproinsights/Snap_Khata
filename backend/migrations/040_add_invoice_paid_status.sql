-- ============================================================================
-- MIGRATION 040: ADD INVOICE PAID STATUS TO VENDOR LEDGER TRANSACTIONS
-- Adds `is_paid` and `linked_transaction_id` columns for tracking paid status
-- Optional: Adds a foreign key to link an auto-generated payment back to the invoice.
-- ============================================================================

ALTER TABLE vendor_ledger_transactions 
ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS linked_transaction_id INTEGER REFERENCES vendor_ledger_transactions(id) ON DELETE SET NULL;

SELECT 'Migration 040: Added invoice paid status columns successfully' as status;
