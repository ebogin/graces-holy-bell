# Handoff — Share with a Friend QR Waitlist

**For:** a local AI instance running on Eric's Mac (with Xcode + iOS simulator).
**Branch:** `claude/referral-qr-waitlist-9nwt3d` (committed & pushed — `git pull` / checkout it).
**Status:** Feature code complete. **Not yet built in Xcode** and **backend not yet deployed.**

---

## Why this handoff exists

The previous instance ran in a **remote Linux cloud sandbox** (Claude Code on the
web). It could write code, run the Node-based backend tests, and push to GitHub —
but it has **no macOS, Xcode, or iOS simulator**, so it could not compile the app
or boot a sim. Those steps need a real Mac. That's your job.

To pick up:
```bash
git fetch origin
git checkout claude/referral-qr-waitlist-9nwt3d
```

---

## What this feature is

A viral referral/waitlist flow for the (beta) app:

1. Settings → **Share with a Friend** (row sits **above** Privacy Policy) opens a
   sheet with the user's **personal QR code** in the app's LCD-green style.
2. A friend scans it → a green-styled **web form** (email, name, country, phone —
   **all optional**) on boginfactory.com.
3. Submitting → a **thank-you page** ("you're on the beta list, we'll reach out")
   that shows the submitter's **own** unique share link (referrals chain), and
   triggers a **confirmation email** containing that same link.
4. Admin gets the data as a **spreadsheet** (CSV export) + a per-signup email.
5. **No public ranked list.** Privacy policy updated with a signup exception.

### Decisions already made (do NOT re-litigate)
- **Backend:** Cloudflare Worker + **Resend** for email (chosen over Apps Script
  specifically because the Worker is debuggable via `wrangler tail` and lives in
  the repo).
- **Referral attribution:** **anonymous per-install code** in the link
  (`?ref=<code>`). Eric maps codes → names himself (he knows current users).
- **Email sender:** `gracesholybell@boginfactory.com` (a Google Workspace
  mailbox), sent via Resend after domain verification.
- **Hosting:** static pages live in `docs/` here as the **source copy**, but
  `boginfactory.com` is actually served by a **separate repo**
  (`ebogin/Boginfactory-Landing-Page`). Pages must be **mirrored** into that
  repo's root to go live — editing `docs/` here does nothing to the live site.
  See the ⚠️ warning in `waitlist/SETUP.md` Step 6. (The privacy policy follows
  this same mirror pattern.)

---

## What was implemented (file by file)

### iOS app (`Graces Holy Bell/`)
- `Views/SettingsView.swift` — added a **Share with a Friend** row above the
  Privacy Policy row + a `.sheet` presenting `ShareWithFriendView`.
- `Views/ShareWithFriendView.swift` *(new)* — green-themed sheet: personal QR +
  native `ShareLink`. Mirrors `PrivacyPolicyView`'s header/DONE styling.
- `Utilities/WaitlistLink.swift` *(new)* — mints/stores an anonymous 8-char
  referral code in UserDefaults; builds the share URL
  (`https://boginfactory.com/grace-waitlist.html?ref=<code>`).
- `Utilities/QRCodeGenerator.swift` *(new)* — on-device QR via CoreImage
  (`CIQRCodeGenerator` + `falseColor`), tinted to the LCD palette.
- `Views/PrivacyPolicyView.swift` — added a **WAITLIST SIGNUP** section, reworded
  intro/"WHAT WE COLLECT", effective date → **June 18, 2026**.
- `PrivacyInfo.xcprivacy` — comment only (UserDefaults reason already declared;
  the app binary still collects no data, so `NSPrivacyCollectedDataTypes` stays
  empty — the form is a website, not the app).

### Web (`docs/`)
- `grace-waitlist.html` *(new)* — green signup form, honeypot, mints submitter's
  own code client-side, POSTs JSON to the Worker, then redirects to the thanks
  page. **Contains a placeholder that MUST be replaced — see below.**
- `grace-waitlist-thanks.html` *(new)* — confirmation + the submitter's unique
  share link (copy + native share).
- `graces-privacy-policy.html` — same WAITLIST SIGNUP section as the Swift view
  (keep the two in sync; both carry effective date June 18, 2026).

### Backend (`waitlist/`)
- `src/index.js` — Cloudflare Worker: validates input, stores to D1, sends
  confirmation + admin emails via Resend, token-protected `/export.csv`.
- `test/index.test.js` — 9 unit tests, **all passing** (`node --test`, no
  Cloudflare account needed).
- `wrangler.toml`, `schema.sql`, `package.json`, `.gitignore`.
- `SETUP.md` — the full backend deployment walkthrough (authoritative).

---

## Remaining work (your tasks)

### 1. Build & run in the iOS simulator
```bash
xcodebuild -project "Graces Holy Bell.xcodeproj" \
  -scheme "Graces Holy Bell" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
# (use `xcrun simctl list devices available` if iPhone 16 isn't installed)
```
Or just open `Graces Holy Bell.xcodeproj` and press Run.

**Manual test:** Settings → **Share with a Friend** → QR sheet renders in green;
tap **Share Link** → share sheet shows a `...grace-waitlist.html?ref=...` URL.

**If the build fails on missing types** (`ShareWithFriendView`, `WaitlistLink`,
`QRCodeGenerator`): the project uses Xcode 16 *synchronized file groups*, so new
files under `Graces Holy Bell/` should auto-include. If your Xcode version
doesn't, right-click the group → **Add Files to "Graces Holy Bell"** → select the
three new files, **iOS target only**. (Same caveat the repo's HANDOFF.md notes
for the Watch `DesignSystem.swift`.)

> The previous instance could not compile this — treat a clean build + the manual
> test above as the acceptance check for the app side.

### 2. Deploy the backend
Follow **`waitlist/SETUP.md`** end to end (Cloudflare login → D1 create + schema →
Resend domain verify + API key → `wrangler secret put RESEND_API_KEY` /
`ADMIN_TOKEN` → `wrangler deploy`). Requires Eric's Cloudflare + Resend logins and
DNS access for boginfactory.com.

### 3. Wire the website to the Worker
In `docs/grace-waitlist.html`, replace:
```js
const WORKER_ENDPOINT = "https://REPLACE-ME.workers.dev";
```
with the deployed Worker URL and commit. **Then publish:** mirror
`grace-waitlist.html` and `grace-waitlist-thanks.html` into the root of
`ebogin/Boginfactory-Landing-Page` and push there — that repo (not this one)
serves boginfactory.com. See the ⚠️ warning in `waitlist/SETUP.md` Step 6.

### 4. End-to-end test
Open `https://boginfactory.com/grace-waitlist.html?ref=testcode`, submit your own
email, confirm: thank-you page shows a share link, two emails arrive
(confirmation + admin), and the CSV export
(`/export.csv?token=<ADMIN_TOKEN>`) has the row with `referrer=testcode`.
Debug with `npx wrangler tail` (streams live Worker logs).

---

## Guardrails / gotchas
- **Keep privacy policy copies identical:** `PrivacyPolicyView.swift` and
  `docs/graces-privacy-policy.html` — same text, same effective date.
- **Don't print the model identifier** in any committed artifact.
- The Worker rejects fully-empty submissions and bot honeypot hits; all real
  fields remain optional.
- Referral code minted in the browser (form) and on-device (app) use the same
  unambiguous alphabet — keep them consistent if you touch either.
- Do **not** open a PR unless Eric asks.
