-- Add whatsapp_custom_note column to user_profiles table if it exists
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS whatsapp_custom_note TEXT;

-- Add whatsapp_custom_note column to user_profile table if it exists
ALTER TABLE user_profile ADD COLUMN IF NOT EXISTS whatsapp_custom_note TEXT;
