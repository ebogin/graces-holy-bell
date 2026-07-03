# Grace's Holy Bell — Waitlist Backend Setup

This is the backend for the "Share with a Friend" waitlist. It's a single
Cloudflare Worker that:

- stores signups in a Cloudflare **D1** database,
- emails the submitter a confirmation (with their own share link) via **Resend**,
- emails **you** a notification for each signup,
- and exposes a token-protected **CSV export** you can open in Google Sheets/Excel.

You'll do this once. Everything below uses the `npx wrangler` CLI — no global
installs required. Run all commands from inside this `waitlist/` folder.

Total time: ~20 minutes, most of it waiting on DNS.

---

## What you need

- A **Cloudflare** account (free) — https://dash.cloudflare.com/sign-up
- A **Resend** account (free) — https://resend.com
- Access to **DNS for boginfactory.com** (to verify the sending domain)
- Node.js 18+ installed locally

---

## Step 1 — Log in to Cloudflare

```bash
cd waitlist
npx wrangler login
```

This opens a browser to authorize the CLI. (`npx` will download wrangler the
first time — say yes.)

---

## Step 2 — Create the D1 database

```bash
npx wrangler d1 create grace-waitlist
```

It prints a block like:

```
[[d1_databases]]
binding = "DB"
database_name = "grace-waitlist"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Copy the `database_id` value and paste it into **`wrangler.toml`**, replacing
`REPLACE_WITH_DATABASE_ID`.

Then create the table:

```bash
npx wrangler d1 execute grace-waitlist --remote --file=./schema.sql
```

---

## Step 3 — Set up Resend (email)

1. Sign up at https://resend.com and go to **Domains → Add Domain**.
2. Enter `boginfactory.com`.
3. Resend shows ~3 DNS records (SPF/DKIM, all `TXT`/`CNAME`). Add each one to
   boginfactory.com's DNS. (If your DNS is already on Cloudflare, this is in the
   same dashboard under that domain's **DNS** tab.)
4. Wait for Resend to show the domain as **Verified** (usually minutes, up to a
   few hours). You can't send from `gracesholybell@boginfactory.com` until it is.
5. Go to **API Keys → Create API Key**, give it Send access, and copy the key
   (starts with `re_`). You'll paste it in the next step.

> The "from" address is set in `wrangler.toml` as
> `FROM_EMAIL = "Grace's Holy Bell <gracesholybell@boginfactory.com>"`.
> It must be on the domain you verified above.

---

## Step 4 — Set the secrets

These are stored encrypted by Cloudflare, never in the repo:

```bash
# Paste the Resend key (re_...) when prompted:
npx wrangler secret put RESEND_API_KEY

# Make up a long random password — this protects the CSV export URL:
npx wrangler secret put ADMIN_TOKEN
```

Save the `ADMIN_TOKEN` somewhere safe; you'll need it to download signups.

---

## Step 5 — Deploy

```bash
npx wrangler deploy
```

It prints your Worker URL, e.g.:

```
https://grace-waitlist.<your-subdomain>.workers.dev
```

Copy that URL.

---

## Step 6 — Point the website at the Worker

In **`docs/grace-waitlist.html`**, find this line near the bottom:

```js
const WORKER_ENDPOINT = "https://REPLACE-ME.workers.dev";
```

Replace it with your Worker URL from Step 5 and commit it here (this repo holds
the source-of-truth copy). **Then publish it — see the warning below.**

> ### ⚠️ IMPORTANT — boginfactory.com is NOT served by this repo
> The pages under `docs/` here are the **source copy only**. The live site
> `boginfactory.com` is served by GitHub Pages from a **separate repo**:
> **`ebogin/Boginfactory-Landing-Page`** (it holds the `CNAME = boginfactory.com`
> and a flat set of HTML files at its root). `graces-holy-bell` does **not** have
> Pages pointed at boginfactory.com.
>
> To actually publish a web page (the waitlist form, the thank-you page, the
> privacy policy), you must **mirror it into the root of
> `Boginfactory-Landing-Page` and push there** — editing `docs/` in this repo
> alone changes nothing on the live site. This is the same mirror pattern noted
> for the privacy policy (`graces-privacy-policy.html` lives in both repos).
>
> So for the waitlist, copy **both** `grace-waitlist.html` and
> `grace-waitlist-thanks.html` into `Boginfactory-Landing-Page`'s root, commit,
> and push. Pages there typically publishes within a minute or two.

---

## Step 7 — Test it end to end

1. Open `https://boginfactory.com/grace-waitlist.html?ref=testcode` in a browser.
2. Enter your own email and submit.
3. You should land on the "You're on the list" page with a share link, and
   receive **two** emails (your confirmation + the admin notification).
4. Download the spreadsheet (see below) and confirm the row is there with
   `referrer = testcode`.

If something fails, watch live logs while you submit:

```bash
npx wrangler tail
```

This streams the Worker's `console.log`/errors to your terminal in real time —
paste anything red here and I can debug it.

---

## Getting the spreadsheet (admin)

Download all signups as CSV (open directly in Google Sheets or Excel):

```
https://grace-waitlist.<your-subdomain>.workers.dev/export.csv?token=YOUR_ADMIN_TOKEN
```

Columns: `created_at, email, name, country, phone, referrer, my_code`.

- `referrer` = the code of the person who shared the link they used. You know
  which code belongs to which current user, so this is your attribution column.
- `my_code` = the new submitter's own code, in case they shared it onward.

Referral link clicks/scans (not just signups) are logged separately —
download them the same way, with the same token:

```
https://grace-waitlist.<your-subdomain>.workers.dev/export-clicks.csv?token=YOUR_ADMIN_TOKEN
```

Columns: `created_at, code, source, device, country`. See
`../planning/referral-click-tracking-spec.md` for the `/r/<code>` short-link
route this data comes from, and how to flip it from redirecting to the
waitlist page to redirecting to the App Store post-launch.

To import into Google Sheets: **File → Import → Upload**, or just open the URL
and `File → Save As`.

---

## Local development (optional)

```bash
npm install          # installs wrangler locally
npm test             # runs the handler unit tests (no account needed)
npm run dev          # runs the Worker locally at http://localhost:8787
```

For `npm run dev` to send real emails you'd put `RESEND_API_KEY=re_...` in a
`.dev.vars` file (gitignored). Without it, signups still store locally and the
email step is skipped.

---

## Reference — config & secrets

| Where | Name | Purpose |
|---|---|---|
| `wrangler.toml` `[[d1_databases]]` | `database_id` | Your D1 database (Step 2) |
| `wrangler.toml` `[vars]` | `ALLOWED_ORIGIN` | CORS allowlist (boginfactory.com) |
| `wrangler.toml` `[vars]` | `FROM_EMAIL` | Verified Resend sender |
| `wrangler.toml` `[vars]` | `ADMIN_EMAIL` | Who gets signup notifications |
| secret | `RESEND_API_KEY` | Resend send key (Step 3) |
| secret | `ADMIN_TOKEN` | Password for the CSV export (Step 4) |
| `docs/grace-waitlist.html` | `WORKER_ENDPOINT` | Your Worker URL (Step 6) |
