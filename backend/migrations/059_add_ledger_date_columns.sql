-- Migration 059: Add latest_bill_date, last_payment_date, latest_bill_number
-- to customer_ledgers and vendor_ledgers tables.
-- These columns power the party card display and sort order on the Parties list.

ALTER TABLE customer_ledgers
  ADD COLUMN IF NOT EXISTS latest_bill_date   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_payment_date  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS latest_bill_number TEXT;

ALTER TABLE vendor_ledgers
  ADD COLUMN IF NOT EXISTS latest_bill_date   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_payment_date  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS latest_bill_number TEXT;

SELECT 'Migration 059: added latest_bill_date, last_payment_date, latest_bill_number to customer_ledgers and vendor_ledgers successfully!' AS status;
