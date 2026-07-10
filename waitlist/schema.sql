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

-- Signup rate limiting: one row per accepted-for-processing POST, keyed by a
-- SHA-256 hash of the client IP (the raw address is never stored). The Worker
-- counts rows in the last hour per ip_hash and rejects past the cap. The
-- Worker FAILS OPEN if this table is missing, but apply it promptly — until
-- then the signup endpoint has no rate limit.
CREATE TABLE IF NOT EXISTS rate_events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  ip_hash    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rate_events_ip_created ON rate_events (ip_hash, created_at);

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

-- Remotely-configurable app content (e.g. the idle-screen welcome message).
-- One row per config key; `value` is an opaque JSON document the Worker never
-- interprets beyond size/JSON validation on write. See WELCOME_MESSAGE.md at
-- the repo root for the schema of the "welcome" key and how to update it.
CREATE TABLE IF NOT EXISTS app_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,   -- JSON document, opaque to the Worker
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
