# Conversation Handoff — Grace's Holy Bell "Share with a Friend" QR Waitlist

**Conversation/decision summary** (companion to `WAITLIST_HANDOFF.md`). Date: 2026-06-22.
**Repo:** `ebogin/graces-holy-bell` · **Branch:** `claude/referral-qr-waitlist-9nwt3d` (pushed).

This summarizes the *conversation/decisions* for a fresh agent. It does **not**
duplicate the implementation handoff or setup guide — read those first:

- In-repo feature handoff: **`WAITLIST_HANDOFF.md`** (file-by-file changes, remaining tasks, gotchas).
- Backend deploy guide: **`waitlist/SETUP.md`** (authoritative steps).
- Worker tests: **`waitlist/test/index.test.js`** (9 passing, `node --test`).
- Commits on the branch: `d52bbdb` (feature), `1e3504e` (handoff). Diffs are the source of truth for code.

---

## Where things stand
- Feature code is **complete, committed, and pushed**. Working tree clean.
- **Not yet done:** (1) build/run the iOS app in a simulator; (2) deploy the
  Cloudflare Worker + Resend backend; (3) replace the `WORKER_ENDPOINT`
  placeholder in `docs/grace-waitlist.html`; (4) end-to-end test. See
  `WAITLIST_HANDOFF.md` → "Remaining work".

## Critical environment fact (caused confusion this session)
This Claude Code session runs in a **remote Linux cloud sandbox**, not on the
user's Mac. It cloned the repo fresh and can run cross-platform tooling (Node
tests passed) but has **no macOS / Xcode / iOS simulator** — so it cannot build
the app or boot a sim. The user expected it to be running locally on their Mac.
A *local* agent on the Mac can do the Xcode build; a sandboxed one cannot. If
the user asks to "build in a sim," clarify which environment you're in before
promising it.

## Decisions locked (do not re-litigate)
- **Backend:** Cloudflare Worker + **Resend** email (picked over Google Apps
  Script because the Worker lives in the repo and is debuggable via
  `wrangler tail`; the user had prior pain with un-debuggable Apps Script).
- **Storage/admin sheet:** Cloudflare **D1** + token-protected `/export.csv`
  (open/import into Google Sheets).
- **Referral attribution:** **anonymous per-install code** in `?ref=`; the user
  maps codes→names himself (knows current beta users). No public list.
- **Email sender:** `gracesholybell@boginfactory.com` (confirmed Google
  Workspace mailbox), via Resend after domain verification.
- **Hosting:** static pages in `docs/` → GitHub Pages → boginfactory.com.
- All form fields (email, name, country, phone) **optional**; honeypot + empty
  rejection on the Worker.

## Open / watch-outs
- Keep the two privacy-policy copies identical: `PrivacyPolicyView.swift` and
  `docs/graces-privacy-policy.html` (both effective **June 18, 2026**).
- Xcode 16 synchronized groups *should* auto-include the 3 new Swift files; if
  not, add them manually (iOS target only) — see `WAITLIST_HANDOFF.md`.
- Do **not** open a PR unless the user asks.

## Sensitive info
None present in this conversation. `RESEND_API_KEY` and `ADMIN_TOKEN` are created
by the user during deploy and stored as Cloudflare secrets — never commit them.
`wrangler.toml` intentionally holds only non-secret vars + a `database_id`
placeholder.

---

## Suggested skills for the next session
- **`run`** — launch the iOS app (build + boot simulator) to confirm the
  Settings → Share with a Friend → QR flow renders. *(Requires a macOS/Xcode
  environment; not possible from a Linux sandbox.)*
- **`verify`** — after the build, manually verify the share sheet produces a
  `grace-waitlist.html?ref=...` URL, then verify the deployed web form →
  thank-you → confirmation email end to end.
- **`security-review`** — this introduces the project's first public
  data-collection endpoint (Worker + form). Review CORS, input validation,
  honeypot, the token-protected export, and email injection escaping.
- **`code-review`** — optional pass over the branch diff before any PR.
