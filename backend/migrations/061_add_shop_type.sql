-- Add shop_type column to user_profiles and user_profile tables
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS shop_type TEXT DEFAULT 'general';
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS shop_type TEXT DEFAULT 'general';
