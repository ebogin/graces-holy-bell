# Grace's Holy Bell — Viral Growth & Sharing Plan (Component 2 of 2)

> Status: planning. **This is the SECOND of two plans and is built second** —
> *after* the analytics plan is live and producing clean data with the beta
> testers. Sibling: [`analytics-plan.md`](analytics-plan.md). Project context &
> locked decisions: [`project-handoff.md`](project-handoff.md).
>
> ⚠️ **UX-review gate:** before any of this is built, the sharing user experience
> (the in-app Share screen, the link/QR flow, the waitlist landing, and the
> deferred-deep-link first-run) gets a dedicated design/UX review. Do **not** start
> implementation until that review is done.

## Goal

Drive **organic viral growth** — person-to-person sharing that compounds. After
App Store launch this is the explicit **#1 priority**. The core number is the
**K-factor (viral coefficient)**: how many new users each sharing user brings.

## Depends on

- The analytics foundation from the analytics plan: the anonymous **`install_id`**
  (which doubles as the **referral code**) and the PostHog event pipeline. This
  plan adds the sharing surfaces, the attribution bridge, and the funnel events on
  top of it.

## What already exists on `main`

The "Share with a Friend" feature is live in Beta:

- `WaitlistLink.referralCode` mints an 8-char anonymous code (UserDefaults); the
  QR / link carries `?ref=CODE`.
- Cloudflare **Worker + D1 `signups`** + Resend record each waitlist signup with
  `referrer` (who shared) and `my_code` (the new signer's own code), and email
  confirmation/admin notices. CSV export is token-gated.

So the **referral graph already exists server-side** during Beta.

## 1. The viral loop — Beta vs. post-launch

### Beta phase (now)
The referral loop exists **solely to aggregate a waitlist**. Beta K-factor is
measured from the D1 referral graph plus top-of-funnel app events and a
`waitlist_view` ping:

`Beta K = waitlist_signups_attributed_to_referrals ÷ sharing_users`

### Post-launch (App Store)
Organic growth is measured from **App Store installs**. Caveat: a bare App Store
link does **not** carry a referrer through install — Apple gives no per-link
organic attribution. So post-launch K-factor needs a **deferred deep-link**
mechanism to connect "who shared" → "who installed":

`Organic K = installs_attributed_to_referrals ÷ sharing_users`

## 2. Deferred deep-linking — decision

### Trade-off assessment (kept for the record)

| Option | Engineering complexity | Attribution accuracy | App Privacy manifest impact |
|---|---|---|---|
| **Third-party SDK** (Branch / AppsFlyer) | Low–medium: drop-in SDK, vendor dashboard | High — deterministic deferred links | Heaviest if used for cross-company ad tracking (ATT + "Data Used to Track You"). **First-party mode avoids this.** |
| **Homegrown IP / User-Agent matching** (Cloudflare) | High: build + tune the matcher | Probabilistic / fuzzy — degrades on shared IPs, CGNAT, VPNs | Light, but IP + UA are personal data under GDPR |
| **Authenticated sign-in** (Apple / Google) | Medium: account system + auth flows | Deterministic — exact, durable | Introduces accounts/PII; biggest departure from anonymous stance |

### Decided: Branch, first-party mode

**Use Branch, configured for first-party deferred deep-linking — no IDFA, no ATT
prompt.** Chosen over AppsFlyer because it is purpose-built for organic referral /
deep-linking, simpler for a solo PM, and cheaper at this stage (AppsFlyer's
strength is paid-ad attribution we are not using). On onboarding: sign Branch's
DPA, select EU data hosting, verify current free-tier limits.

Why no ATT penalty: **ATT only governs *cross-company* tracking.** Person-to-person
referral is *first-party* (our link → our app), so it is not "tracking" under
Apple's definition — no ATT pop-up, no IDFA, and none of the ~75% opt-out data
loss. **ATT re-enters scope only if paid advertising is added later** (a separate
decision). No official Branch MCP exists — drive Branch via its API/dashboard.

Branch is the project's **single third-party SDK beyond PostHog**, and is added
**near App Store launch** — it is not needed during Beta (the waitlist already
captures referral server-side).

## 3. Viral events (extend the PostHog taxonomy)

| Event | Fires when | Properties |
|---|---|---|
| `share_screen_opened` | "Share with a Friend" opened | `device_source` |
| `share_initiated` | The in-app **Share Link** button is pressed | `device_source` |
| `waitlist_view` | The waitlist landing page is viewed | `referrer` (from `?ref=`) |
| `install_attributed` | First app launch carrying a referrer (via Branch) | `referrer` |

Also: `app_installed` (defined in the analytics plan) gains a `referrer` property
when Branch resolves a deferred link.

**QR caveat:** `share_initiated` fires **only** on the Share Link button. The app
cannot detect a QR *scan*, so QR conversions surface only downstream as
`waitlist_view` / signups carrying the `referrer` code.

## 4. Backend (Cloudflare, mostly existing)

- **Existing:** the waitlist Worker + D1 `signups` (with `referrer` / `my_code`),
  Resend emails, token-gated CSV export.
- **To add:** a lightweight **`waitlist_view` ping** so we measure page-view →
  signup conversion (not just completed signups). Uses the `wrangler` /
  `cloudflare` skills.
- Consider a Turnstile challenge on the form to keep the referral graph bot-clean.

## 5. K-factor & funnel analysis

Full funnel, app → waitlist/App Store → install → activation → re-share:

`share_screen_opened` → `share_initiated` → `waitlist_view` (`referrer`) →
signup (`referrer`, `my_code`) → `install_attributed` (`referrer`) →
`session_ended` (activation, from analytics plan) → re-share.

Sub-metrics isolate which stage to fix: share→signup, signup→install,
install→activation. Headline: **K > 1 = self-compounding growth.**

## 6. Privacy & App Store deltas (only when Branch is added)

- Update `PrivacyInfo.xcprivacy` for the Branch SDK.
- Re-check App Store Connect "App Privacy": adding deterministic referral
  attribution may add an **Identifiers** entry; first-party mode should keep it
  *not* "Data Used to Track You" — confirm at integration time.
- Update the privacy policy to disclose Branch as a processor (sign its DPA, EU
  hosting).

## 7. UX review (the gate, before build)

Review and sign off the sharing experience *before* implementation:

- The in-app **Share screen** (current QR + Share Link) — is it the experience we
  want, or does the loop need redesign (incentive, copy, when/where it's surfaced)?
- The **waitlist landing** the friend hits (and post-launch, the App Store →
  deferred-deep-link first-run experience).
- Whether/where to prompt sharing inside the app (and not undermining the calm,
  non-interventionist product tone).

## 8. Phasing (this plan, built second)

0. **UX review** 🧍🔎 — sign off the sharing experience (above) before building.
1. **Beta funnel instrumentation:** `share_screen_opened`, `share_initiated`, and
   the `waitlist_view` ping; wire Beta K-factor analysis in PostHog + the D1
   referral graph.
2. **Near-launch — Branch attribution:** add the Branch SDK (first-party, no IDFA,
   no ATT), Universal Links / associated-domains, deferred deep link,
   `install_attributed`, and organic K-factor. 🧍 (Branch account + DPA by owner)
3. **Growth dashboard:** the full funnel + K-factor views (PostHog MCP).

> Triggered later, only when an App Store launch date is real. ATT/IDFA stay out
> unless/until paid advertising is added.
