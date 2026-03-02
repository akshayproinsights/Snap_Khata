-- migrations/025_add_customer_mobile_to_verification.sql
-- Add customer_name and mobile_number to the review verification tables

ALTER TABLE verification_dates
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS mobile_number BIGINT;

ALTER TABLE verification_amounts
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS mobile_number BIGINT;
