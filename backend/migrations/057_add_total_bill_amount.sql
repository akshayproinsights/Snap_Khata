-- Migration: Add total_bill_amount to all invoice-related tables
-- This ensures the UI can correctly display and persist "Total Bill" in the Review Tab

-- 1. invoices table (staging table)
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS total_bill_amount NUMERIC DEFAULT 0;

-- 2. verification_dates table (review header table)
ALTER TABLE verification_dates ADD COLUMN IF NOT EXISTS total_bill_amount NUMERIC DEFAULT 0;

-- 3. verification_amounts table (review line item table)
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS total_bill_amount NUMERIC DEFAULT 0;

-- 4. verified_invoices table (final output table)
ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS total_bill_amount NUMERIC DEFAULT 0;

-- Notify PostgREST to reload the schema cache so the API picks up the new columns immediately
NOTIFY pgrst, 'reload schema';
