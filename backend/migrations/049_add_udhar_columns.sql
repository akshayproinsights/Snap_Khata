-- Migration 049: Add balance_due and received_amount to verified_invoices
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS balance_due NUMERIC DEFAULT 0;
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;

SELECT 'Migration 049: added balance_due and received_amount successfully!' as status;
