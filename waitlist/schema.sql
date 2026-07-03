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
  instagram  TEXT,   -- optional Instagram handle from the signup form
  sms_consent TEXT,  -- "yes"/"no": did they authorize SMS messages
  referrer   TEXT,   -- referral code of whoever shared the link they used
  my_code    TEXT,   -- this submitter's own referral code
  source     TEXT    -- share surface the link came from: "phone"/"watch"/""
);

CREATE INDEX IF NOT EXISTS idx_signups_created_at ON signups (created_at);
CREATE INDEX IF NOT EXISTS idx_signups_referrer   ON signups (referrer);

-- Migrations for databases created before these columns existed.
-- Safe to run once on the live DB (errors harmlessly if the column is present):
--   npx wrangler d1 execute grace-waitlist --remote \
--     --command "ALTER TABLE signups ADD COLUMN instagram TEXT"
--   npx wrangler d1 execute grace-waitlist --remote \
--     --command "ALTER TABLE signups ADD COLUMN source TEXT"

-- One row per open/scan of a referral short link (/r/<code>).
CREATE TABLE IF NOT EXISTS ref_clicks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  code       TEXT NOT NULL,  -- referral code from the /r/<code> path
  source     TEXT,           -- share surface from ?src=: "phone"/"watch"/""
  device     TEXT,           -- coarse UA class: "ios"/"android"/"desktop"/"bot"/""
  country    TEXT            -- ISO country from request.cf.country, or ""
);

CREATE INDEX IF NOT EXISTS idx_ref_clicks_code       ON ref_clicks (code);
CREATE INDEX IF NOT EXISTS idx_ref_clicks_created_at ON ref_clicks (created_at);
