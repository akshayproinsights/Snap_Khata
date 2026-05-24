-- Migration: Add user_item_catalogue table
-- Create user_item_catalogue table for SnapKhata item catalog

CREATE TABLE IF NOT EXISTS user_item_catalogue (
  id           SERIAL PRIMARY KEY,
  username     TEXT NOT NULL,
  item_name    TEXT NOT NULL,
  last_price   NUMERIC(10,2) DEFAULT 0,
  unit         TEXT DEFAULT 'NOS',
  use_count    INT DEFAULT 1,
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(username, item_name)
);
