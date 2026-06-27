-- Grace's Holy Bell waitlist storage (Cloudflare D1).
-- Apply with:
--   npx wrangler d1 execute grace-waitlist --remote --file=./schema.sql
CREATE TABLE IF NOT EXISTS signups (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  email      TEXT,
  name       TEXT,
  country    TEXT,
  phone      TEXT,
  sms_consent TEXT,  -- "yes"/"no": did they authorize SMS messages
  referrer   TEXT,   -- referral code of whoever shared the link they used
  my_code    TEXT,   -- this submitter's own referral code
  source     TEXT    -- share surface the link came from: "phone"/"watch"/""
);

CREATE INDEX IF NOT EXISTS idx_signups_created_at ON signups (created_at);
CREATE INDEX IF NOT EXISTS idx_signups_referrer   ON signups (referrer);

-- Migration for databases created before the `source` column existed.
-- Safe to run once on the live DB (errors harmlessly if the column is present):
--   npx wrangler d1 execute grace-waitlist --remote \
--     --command "ALTER TABLE signups ADD COLUMN source TEXT"
