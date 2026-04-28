-- Migration to add missing taxable_row_ids to verified_invoices
ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS taxable_row_ids JSONB DEFAULT '[]'::jsonb;

-- Ensure extra_fields is there (redundant but safe)
ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- Ensure customer_details is there
ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS customer_details TEXT;

-- Ensure car_number and vehicle_number are there
ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS car_number TEXT;

ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
