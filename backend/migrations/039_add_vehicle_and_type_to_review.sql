-- migrations/039_add_vehicle_and_type_to_review.sql
-- Add vehicle_number and type to verification and staging tables

-- 1. verification_dates: Add vehicle_number
ALTER TABLE verification_dates
ADD COLUMN IF NOT EXISTS vehicle_number TEXT;

-- 2. verification_amounts: Add type
ALTER TABLE verification_amounts
ADD COLUMN IF NOT EXISTS type TEXT;

-- 3. invoices: Add type (vehicle_number already exists)
ALTER TABLE invoices
ADD COLUMN IF NOT EXISTS type TEXT;

-- 4. verified_invoices: Add vehicle_number and type
ALTER TABLE verified_invoices
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS type TEXT;
