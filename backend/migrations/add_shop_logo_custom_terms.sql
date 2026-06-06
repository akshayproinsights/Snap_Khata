-- Migration: Add shop_logo_url and custom_terms to user_profiles
-- Run this once against your Supabase/Postgres DB

ALTER TABLE user_profiles 
  ADD COLUMN IF NOT EXISTS shop_logo_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS custom_terms  TEXT DEFAULT '';

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_profiles'
  AND column_name IN ('shop_logo_url', 'custom_terms');
