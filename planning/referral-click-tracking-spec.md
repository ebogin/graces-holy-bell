# Referral click tracking + PostHog sharing dashboards — build spec

Replaces the Branch.io integration from `viral-growth-plan.md` (Branch dropped
its free tier July 2025; we self-host on the existing waitlist Worker instead).
One new GET route on the `waitlist/` Worker, one new D1 table, server-side
PostHog capture, and a one-line app change. No new vendors, no PII collected.
Nothing is shown to end users — the audience for this data is admin-side
PostHog dashboards.

## Goals

1. **Stable short link** `https://boginfactory.com/r/<code>` that the QR
   encodes. It never changes; where it *redirects* flips from the waitlist page
   (pre-launch) to the App Store URL (post-approval) via a single env var.
2. **Click log** in D1 so each referral code's reach (scans/opens) is
   measurable, not just its signups. D1 stays the durable source of truth
   (referral-tree queries, CSV exports).
3. **PostHog events** captured server-side by the Worker for every referral
   click and waitlist signup, so sharing dashboards (reach over time, top
   codes, click→signup conversion, phone vs. watch surface) live alongside the
   existing app analytics in the same EU project.

## Privacy constraints (non-negotiable)

- No IP addresses, no raw User-Agent strings, no cookies, no fingerprinting.
- Only store: timestamp, referral code, share surface, coarse device class,
  coarse country (Cloudflare's `request.cf.country`, already computed edge-side).
- `/stats/<code>` returns counts only — never emails, names, or row data.

## D1 schema addition (append to `waitlist/schema.sql`)

```sql
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
```

Apply with the same command documented at the top of `schema.sql`.

## Worker route 1: `GET /r/<code>` — click log + redirect

- **Path match:** `^/r/([a-z0-9]{4,16})$` (codes are currently 8 chars from
  the alphabet in `Shared/WaitlistLink.swift`; keep the pattern tolerant).
  Invalid/missing code → still redirect to the destination (never strand a
  human on an error page), just skip logging.
- **Query:** `?src=phone|watch` (whitelist exactly as the POST handler does;
  anything else stored as `""`).
- **Log:** INSERT into `ref_clicks` with `created_at` = ISO timestamp,
  `device` classified from the UA header (contains "bot/crawler/preview" →
  `bot`; "iPhone/iPad" → `ios`; "Android" → `android`; else `desktop`;
  missing → `""`). Store the *class only*, discard the raw UA. Bots are logged
  (flagged) but still redirected. Logging is best-effort: wrap in try/catch;
  a D1 failure must never block the redirect (same philosophy as the
  best-effort emails in `sendEmails`).
- **Redirect:** `302` to a destination controlled by env var:
  - `REDIRECT_URL` unset/empty → default
    `https://boginfactory.com/grace-waitlist.html?ref=<code>&src=<src>`
    (carries attribution through to the form, exactly like today's direct link).
  - `REDIRECT_URL` set (post-approval, the App Store URL) → redirect there
    verbatim. The App Store URL can't carry `ref`, which is fine — the click
    row already recorded the attribution. **This env var flip is the entire
    TestFlight/App-Store cutover.**
- Add `Cache-Control: no-store` on the redirect so every scan hits the Worker.

## PostHog server-side capture (powers the sharing dashboards)

The Worker sends events to the existing EU PostHog project via plain HTTP —
no SDK dependency, one small helper:

- `POST https://eu.posthog.com/i/v0/e/` with JSON body
  `{ api_key, event, distinct_id, properties, timestamp }`.
- `api_key` is the project API key (`phc_…`) — it is a *public* write-only
  token, same one the app already embeds, so it can live as a plain var in
  `wrangler.toml` (not a secret). Name it `POSTHOG_API_KEY`; if unset, skip
  capture silently.
- Capture is **best-effort and non-blocking**: use
  `ctx.waitUntil(...)` so it never delays the redirect or signup response,
  and never fails the request (same philosophy as the Resend emails).
  Note: `handleRequest(request, env)` must gain a `ctx` parameter threaded
  from the default export's `fetch(request, env, ctx)`.

Two events:

1. `referral_link_clicked` — from `/r/<code>`, skipped for `device == "bot"`.
   - `distinct_id`: `"ref:" + code` (the anonymous share code — deliberately
     NOT a person identity; it identifies the *sharer's install*, consistent
     with labels-only privacy).
   - properties: `ref_code`, `source` (phone/watch/""), `device`
     (ios/android/desktop), `country`, `destination` ("waitlist"/"appstore"),
     and `$process_person_profile: false` (events-only, no person profiles —
     keeps PostHog costs at the cheaper anonymous-event rate and avoids
     implying identity).
2. `waitlist_signup` — from the existing POST handler, after the D1 insert
   succeeds.
   - `distinct_id`: `"ref:" + (referrer || "organic")`.
   - properties: `ref_code` (the referrer's code or "" if organic),
     `new_code` (the signup's own `my_code` — enables second-generation
     dashboards), `source`, `has_email` (boolean — NOT the email itself),
     `$process_person_profile: false`.
   - **No PII in properties**: never send email/name/phone/instagram/country
     from the form to PostHog. (Cloudflare edge `country` on clicks is fine —
     it's coarse and never tied to a person.)

### Dashboards to build after events flow (manual/MCP step, not Worker code)

- Reach over time: `referral_link_clicked` trend, broken down by `source`.
- Top sharers: `referral_link_clicked` + `waitlist_signup` broken down by
  `ref_code` (power-connector leaderboard).
- Conversion funnel: `referral_link_clicked` → `waitlist_signup` (correlate
  via `ref_code`).
- Pre/post-launch mix: breakdown by `destination` to watch the App Store flip.
- Deep referral-tree analysis (multi-generation chains) stays a D1 SQL job —
  event breakdowns can't recurse; that's why D1 remains source of truth.

## Wiring notes (things that will bite if skipped)

1. **Method gate:** `handleRequest` currently 405s everything that isn't POST
   or `/export.csv`. The two new GET matches must be added *before* that check.
2. **Routes:** the Worker must own `boginfactory.com/r/*`. Add a `routes`
   entry in `waitlist/wrangler.toml`
   (the site itself is served by the separate `ebogin/Boginfactory-Landing-Page`
   repo — these Worker routes take precedence on those paths; no landing-page
   repo changes and therefore no docs/ mirroring needed).
3. **App change:** `Shared/WaitlistLink.swift` `shareURL` becomes
   `https://boginfactory.com/r/<code>?src=<source>` (build via URLComponents as
   now). Everything downstream (QR on phone + watch) picks this up untouched.
   Keep `baseURL` for the waitlist page since the Worker still redirects to it.
4. **Admin visibility:** extend `/export.csv` or add `/export-clicks.csv`
   (same `ADMIN_TOKEN` gate) so click data is inspectable without wrangler.
   Reuse the existing csvCell/header pattern.
5. **Tests:** `waitlist/test/` exists — cover: valid click logs + redirects,
   invalid code still redirects without logging, `REDIRECT_URL` flip, bot
   classification (bot logged in D1 but no PostHog event), PostHog capture
   fired with correct event/properties on click and signup (mock fetch),
   PostHog failure/missing key never affects the response, no-PII assertion
   on the signup event payload, D1 insert failure still redirects.

## Later (not this build)

- Build the PostHog dashboards listed above once real events flow (can be done
  via the PostHog MCP from a Claude session).
- Power-connector leaderboard export from D1: a `GET /export-reach.csv`
  joining clicks × signups × second-generation signups per code (same
  `ADMIN_TOKEN` gate as `/export.csv`).
