-- Add shop_upi_id column to user_profiles table
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS shop_upi_id TEXT;
