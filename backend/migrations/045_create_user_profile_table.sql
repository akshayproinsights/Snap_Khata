-- migration to create user_profile table and migrate data from user_profiles if it exists

-- 1. Create user_profile table
CREATE TABLE IF NOT EXISTS user_profile (
    username TEXT PRIMARY KEY,
    shop_name TEXT,
    site_contact TEXT, -- Equivalent to user name
    mobile_number TEXT,
    address TEXT,
    shop_gst TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Migrate data from user_profiles if it exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profiles') THEN
        INSERT INTO user_profile (username, shop_name, site_contact, mobile_number, address, shop_gst)
        SELECT username, shop_name, username, shop_phone, shop_address, shop_gst
        FROM user_profiles
        ON CONFLICT (username) DO NOTHING;
        
        -- Optionally drop the old table after verification, but for now let's keep it safe.
        -- DROP TABLE user_profiles;
    END IF;
END $$;

-- 3. Enable RLS
ALTER TABLE user_profile ENABLE ROW LEVEL SECURITY;

-- 4. Create policies
CREATE POLICY "Users can view their own profile"
ON user_profile FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all profiles"
ON user_profile FOR ALL
USING (true) WITH CHECK (true);

-- 5. Add index
CREATE INDEX IF NOT EXISTS idx_user_profile_username ON user_profile(username);
