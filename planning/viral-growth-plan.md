# Grace's Holy Bell — Viral Growth & Sharing Plan (Component 2 of 2)

> Status: planning. **This is the SECOND of two plans and is built second** —
> *after* the analytics plan is live and producing clean data with the beta
> testers. Sibling: [`analytics-plan.md`](analytics-plan.md). Project context &
> locked decisions: [`project-handoff.md`](project-handoff.md).
>
> ⚠️ **UX-review gate:** before any of this is built, the sharing experience (the
> in-app Share screen, the QR/link flow, the **Watch** QR flow, and the waitlist
> landing) gets a dedicated design/UX review. Do **not** start implementation until
> that review is done.

## Goal

Drive **organic viral growth** — person-to-person sharing that compounds. After
App Store launch this is the explicit **#1 priority**.

## How sharing actually happens (the product reality this plan is built around)

Growth is expected to be **mostly in person**: during weekend group prayer, a
friend sees the app in use and asks about it. Because a praying user may be a bit
woozy, **typing a friend's name is hard — showing a QR code is easy.** So:

- **QR is the primary, recommended share method**; the share *link* is secondary.
- **One share is one-to-many:** a single user can show their QR to a *whole group*
  at once. One sharer can recruit several people from one action.
- **Sharing should work on the Watch too** (a QR is far easier than typing on a
  watch). → **TODO: design the Watch QR UI** (own discussion; see §10).
- The app is **anonymous**: we learn *how many* people a sharer brought and the
  referral chain — **never who they are by name** (that would require collecting
  contact info; out of scope).

## Depends on

The analytics foundation: the anonymous **`install_id`** (which doubles as the
**referral code**) and the PostHog pipeline (including the Watch→phone event proxy
and `device_source` tagging). This plan adds sharing surfaces and the referral
funnel on top.

## What already exists on `main`

- `WaitlistLink.referralCode` mints an 8-char anonymous code (UserDefaults); the
  QR / link carries `?ref=CODE`.
- Cloudflare **Worker + D1 `signups`** + Resend record each waitlist signup with
  `referrer` (who shared) and `my_code` (the new signer's own code). CSV export is
  token-gated. **So the referral graph already exists server-side.**

---

## 1. The attribution spine: outgoing → incoming

We measure virality by **matching two ends**, not by inspecting the share itself:

- **Outgoing** = a user shows their QR or opens the share link. This only flags
  *"this person shared."* We do **not** try to detect whether they "completed" a
  share (no `UIActivityViewController` completion handler, no UIKit wrapper) —
  it's unnecessary and, for a QR shown in person, meaningless.
- **Incoming** = one or more friends land on the page carrying that person's
  `?ref=CODE` and some convert (waitlist signup now; App Store install later).

The **incoming side is the scorekeeper.** If someone flashes a QR and nobody
scans, they simply produce zero recruits — no special handling needed. This spine
is sturdy because the **landing page reliably captures the code** regardless of
any deep-link plumbing (see §5).

## 2. Measuring virality — the K-factor model

**K-factor = new users brought in ÷ the people who shared.**

- **Denominator = unique sharers** (by `install_id`) in the period — a user who
  opens the QR once or 100 times counts **once**. **Duds are kept in:** someone who
  shared and recruited nobody stays in the denominator — they are exactly the
  signal that pulls K below 1 and warns you sharing isn't landing.
  - *Why not "only count shares that converted"?* That would make every counted
    sharer a success by definition, forcing K ≥ 1 — a thermometer that only reads
    "fine." It destroys the warning the metric exists to give.
- **Numerator = new users attributed to referral codes:**
  - **Beta:** `Beta K = signups_attributed_to_referrals ÷ unique_sharers`
  - **Post-launch:** `Organic K = installs_attributed_to_referrals ÷ unique_sharers`
- **One-to-many is captured:** all downstream conversions from one code count — a
  single share to a prayer group can yield several recruits.
- **K > 1 = self-compounding growth.**

**Companion diagnostic — Share Conversion Rate:** `% of sharers whose code
produced ≥1 arrival`. This captures the "did the share actually land?" intuition
**without** corrupting K. Kept as a separate number, not folded into the denominator.

**Method (QR vs. link) is a dimension, not a separate K.** Which method a user
chose is *interesting* and tracked in PostHog, but **irrelevant to the K
calculation** — a share is a share. *However*, because **QR is the primary
channel**, we do watch the **QR funnel's health** specifically (scan → landing →
convert), since a clunky QR→Safari→App Store hop is where growth could quietly
leak.

## 3. Viral events (extend the PostHog taxonomy)

All carry `device_source` (`phone` | `watch`) — Watch share events proxy through
the phone's PostHog SDK exactly like the analytics plan's other Watch events.

| Event | Fires when | Properties |
|---|---|---|
| `share_screen_opened` | "Share with a Friend" opened | `device_source` |
| `qr_displayed` | The QR code is shown (primary method; phone or watch) | `device_source` |
| `share_link_opened` | The share-link option is opened (secondary method) | `device_source` |
| `waitlist_view` | A friend lands on the referral page | `referrer`, `channel` (qr / link) |
| `install_attributed` | First app launch carrying a referrer (via Branch, post-launch) | `referrer`, `channel` |

- **A "sharer"** = a unique user who fired `qr_displayed` **or** `share_link_opened`.
- `share_initiated` from the old plan is **removed** (it conflated intent with a
  share and couldn't see QR). Replaced by the two method-specific outgoing events.
- `app_installed` (analytics plan) gains a `referrer` + `channel` property when
  Branch resolves a deferred link.
- We **cannot** see a QR *scan* on the sharer's device — scans surface only as the
  friend's incoming `waitlist_view` / signup carrying the code.

## 4. Channel tagging on the referral URL

To attribute method on the **incoming** side, the share URL carries the channel:
`?ref=CODE&ch=qr` (QR) vs `?ref=CODE&ch=link` (link). The Worker stores `channel`
alongside `referrer`, and `waitlist_view` reads it. This powers the QR-funnel
health view in §2 — it is **not** used to split K.

## 5. Deferred deep-linking — Branch (post-launch only)

During Beta, attribution is 100% via the landing page (the code is in the URL).
**Post-launch**, the open question is connecting a landing-page visitor to their
actual **App Store install** — a bare App Store link drops the referrer. Branch
closes that gap.

### Decided: Branch, first-party mode
**Branch, first-party deferred deep-linking — no IDFA, no ATT prompt.** Chosen
over AppsFlyer (purpose-built for organic referral, simpler, cheaper; AppsFlyer's
edge is paid-ad attribution we don't use). On onboarding: sign Branch's DPA,
select EU hosting, verify free-tier limits. No official Branch MCP — drive via
API/dashboard.

Why no ATT penalty: ATT governs *cross-company* tracking; first-party
person-to-person referral isn't "tracking," so no ATT prompt and no IDFA. **ATT
re-enters scope only if paid advertising is added later.**

### Honest limitation (set expectations now)
Universal Links give *deterministic* routing only for friends who **already have
the app**. For a **brand-new friend** (the actual K driver), the click→install
match happens *after* the App Store trip, which modern iOS constrains heavily. So
**post-launch Organic K is a strong estimate, not ground truth.** Our landing-page
spine (§1) softens this — much attribution lands via the page regardless of
Branch — but the deferred new-install number should be read as directional.

Branch is the project's **single SDK beyond PostHog**, added **near launch only**
(not needed in Beta).

## 6. Backend (Cloudflare, mostly existing)

- **Existing:** waitlist Worker + D1 `signups` (`referrer` / `my_code`), Resend,
  token-gated CSV export.
- **To add:** a lightweight **`waitlist_view` ping** (with `referrer` + `channel`)
  to measure page-view → signup conversion, esp. for the QR funnel. Uses the
  `wrangler` / `cloudflare` skills.
- Consider a Turnstile challenge on the form to keep the referral graph bot-clean.

## 7. Reinstalls — noted and accepted

A delete-and-reinstall mints a new `install_id` ("new install = new user").
Branch's device graph *might* re-attribute such a user to their original referrer,
slightly **over-counting** them as a new recruit. **Decision: accept the small
error.** In an in-person/QR model a fresh scan is almost always a genuinely new
person, so reinstall double-counting is rare and not worth the complexity (or the
mild tension with our anonymous stance) to eliminate.

## 8. Privacy & App Store deltas (only when Branch is added)

- The outgoing→incoming model is privacy-clean: no completion-tracking, no names,
  anonymous codes only.
- Update `PrivacyInfo.xcprivacy` for the Branch SDK.
- Re-check App Store Connect "App Privacy": deterministic referral may add an
  **Identifiers** entry; first-party mode should keep it *not* "Data Used to Track
  You" — confirm at integration.
- Update the privacy policy to disclose Branch as a processor (DPA, EU hosting).

## 9. Pre-launch validation gate (Universal Links / AASA) 🔎

Before App Store submission, **prove the first-party routing is real** — if the
Associated Domains entitlement or the `apple-app-site-association` (AASA) file is
misconfigured, Branch silently falls back to probabilistic matching (degraded
accuracy *and* closer to Apple's "tracking" line). Required checks:

- Associated Domains entitlement present and correct.
- AASA hosted and valid (Apple's AASA validator **and** Branch's link checker).
- A real end-to-end test: tap a referral link on a clean device → confirm correct
  routing and `referrer` capture.

This gate is mandatory before launch.

## 10. UX review (the gate, before build)

Sign off the sharing experience *before* implementation:

- The in-app **Share screen** (QR-first; is the loop right — incentive, copy,
  when/where it's surfaced, without undermining the calm product tone?).
- **Watch QR UI** — **TODO:** design how the QR is shown on the small watch face
  (size/scannability, how it's reached). Dedicated discussion.
- One-to-many ergonomics: showing a QR to a *group* (held up, scannable by several
  people at once).
- The friend's **landing page** (and post-launch, the App Store first-run).

## 11. Phasing (this plan, built second)

0. **UX review** 🧍🔎 — incl. the Watch QR UI design — before building.
1. **Beta funnel instrumentation:** `share_screen_opened`, `qr_displayed`,
   `share_link_opened`, channel-tagged URLs, and the `waitlist_view` ping. Wire
   Beta K (unique sharers) + Share Conversion Rate + the QR-funnel health view in
   PostHog and the D1 referral graph.
2. **Watch sharing:** implement QR sharing on the Watch (per the UX review).
3. **Near-launch — Branch attribution:** add the Branch SDK (first-party, no IDFA,
   no ATT), Associated Domains / AASA + the §9 validation gate, deferred deep
   link, `install_attributed`, Organic K. 🧍 (Branch account + DPA by owner)
4. **Growth dashboard:** K-factor, Share Conversion Rate, the QR vs. link funnels
   (PostHog MCP).

> Triggered later, only when an App Store launch date is real. ATT/IDFA stay out
> unless/until paid advertising is added.
