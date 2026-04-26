-- Migration: Fix schema mismatches in verification_dates and verification_amounts
-- These columns are expected by backend/routes/review.py but were missing in the database

-- Add missing columns to verification_dates
ALTER TABLE verification_dates ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;
ALTER TABLE verification_dates ADD COLUMN IF NOT EXISTS balance_due NUMERIC DEFAULT 0;
ALTER TABLE verification_dates ADD COLUMN IF NOT EXISTS customer_details TEXT;

-- Add missing columns to verification_amounts
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS description_bbox JSONB;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS quantity_bbox JSONB;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS rate_bbox JSONB;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS payment_mode TEXT;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS balance_due NUMERIC DEFAULT 0;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS customer_details TEXT;
ALTER TABLE verification_amounts ADD COLUMN IF NOT EXISTS type TEXT;

-- Verify columns were added
SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name IN ('verification_dates', 'verification_amounts')
ORDER BY table_name, column_name;
