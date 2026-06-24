# Grace's Holy Bell — Project Handoff & Vision

> Purpose of this doc: a complete, self-contained briefing so a fresh session (AI
> or human) can understand the project fully without re-explanation.
> Status: planning. Nothing in the measurement/growth layer is implemented yet.
> Last updated: 2026-06-23.
>
> **The work is split into two plans, built in order:**
> 1. [`analytics-plan.md`](analytics-plan.md) — instrument the app; prove clean
>    data with beta testers. **Built first.**
> 2. [`viral-growth-plan.md`](viral-growth-plan.md) — sharing + referral
>    attribution (Branch). **Built second, after a UX-review gate.**

---

## 1. The product (frozen, do not modify)

**Grace's Holy Bell is a personal prayer-*duration* awareness tool.** In some
denominations, praying too frequently or intensely can cause physical harm
(swooning, fainting). The app doesn't measure intensity and doesn't intervene —
it reflects back the *facts of frequency*: how long since your last prayer, how
many prayers this evening — so a user can self-regulate and notice if they're
praying too often. It is a **personal** tool. A social "let friends watch out for
me" function is a distant maybe, not a current goal.

**Core mechanic:** a "PRAY" slider marks a prayer/"Amen", starting a timed
session. The optional, lightweight **Amen Alarm** fires a local notification a set
interval (30m–2h) after the last prayer. A prayer log shows history/durations.

**Tech (existing, stable, FROZEN):** SwiftUI **iPhone app + Apple Watch
companion**; retro pixel-font / LCD-green aesthetic; **on-device storage** synced
phone↔watch peer-to-peer (WatchConnectivity); **no accounts**; **zero third-party
dependencies**; deployment targets **iOS 26.2 / watchOS 26.2**. Currently in
**Beta via TestFlight** (<10 friends) with a **waitlist + Share-with-a-Friend**
referral, heading toward an undated App Store launch.

Because **duration/interval (not intensity or content)** is the heart of the
product, it is also the heart of the analytics.

## 2. Scope of THIS effort

Bolt a **measurement + growth layer** onto the frozen app, as **two sequenced
plans**:

1. **Analytics first** ([`analytics-plan.md`](analytics-plan.md)) — anonymous
   behavioral instrumentation (PostHog), privacy-policy rewrite + App Store
   privacy answers. Proven with beta testers before component 2 begins.
2. **Viral growth second** ([`viral-growth-plan.md`](viral-growth-plan.md)) —
   sharing surfaces, referral attribution (Branch, near launch), K-factor. Gated
   on a UX review of the sharing experience before build.

Sequencing rationale: get the data layer clean and trustworthy first; the sharing
UX deserves its own review pass before we build the growth machine.

**Out of scope / frozen:** the core prayer experience, mechanics, watch sync, and
UI. Do **not** change prayer behavior — only instrument it. **Prayer content is
never collected, shared, or aggregated** under any circumstance.

## 3. Why — the decisions this data drives

This phase is **exploratory; no numeric targets yet.** The data exists to answer:

- **"Is this worth continuing to invest in?"** (key)
- **"How many people actually find this useful?"**
- **"Is the app actually helping people self-regulate?"**

**North Star:** deferred. Will likely combine **viral K-factor** with **% of
installs that become weekly/monthly habitual, retained users.** After App Store
launch, **viral spread is the explicit top priority.**

**Consumer:** solo PM (the owner), checking in **weekly**. Possible future
audiences: faith leaders, advertisers, external stakeholders (so reporting should
be presentable over time; note "advertisers" interacts with the ATT/privacy
choices in §6).

## 4. Architecture (decided)

- **Frontend:** existing SwiftUI app (frozen). A thin `Analytics` protocol in
  `Shared/` wraps the vendor SDK; view code never touches the SDK directly.
- **Product analytics:** **PostHog (EU Cloud, Frankfurt), full iOS SDK.** Chosen
  for out-of-the-box funnels/retention/cohorts/Lifecycle/Stickiness — clear,
  trustworthy data for a solo PM with no SQL/dashboard-building overhead.
  (Decision: use the SDK, not a thin-HTTP alternative.)
- **Viral attribution:** **Branch, first-party deferred deep-linking, no IDFA, no
  ATT.** Added as the *single* third-party SDK near launch (not needed during
  Beta — the waitlist already captures referral server-side). See §6 for the ATT
  reasoning.
- **Backend:** **Cloudflare** (existing Worker + D1 `signups` + Resend) runs the
  waitlist and any future business logic. Self-hosted, owned, scales.
- **Auth:** **none.** The app stays accountless and anonymous (see §5). Auth would
  only ever return if accounts are wanted for other reasons (cloud sync, etc.) —
  not planned.

## 5. Identity & the two data planes

- **One anonymous identity:** `install_id` = referral code = PostHog
  `distinct_id`. Random, no PII. Unifies the existing `WaitlistLink.referralCode`.
  Also the retention/cohort key.
  - **Shared across devices:** generated on iPhone, **synced to Watch** over the
    existing WatchConnectivity link — the Watch must NOT mint its own, or one
    person counts as two.
  - **Persistence: UserDefaults** (not Keychain) — delete-and-reinstall yields a
    new ID, i.e. "new install = new user." Chosen for simplicity and honest
    anonymity over long-term retention precision.
  - **Single key, not compound.** Everything else rides as PostHog *person/event
    properties*: `first_seen`/`install_date`, `app_version`, `device_source`,
    `country`, `referrer`, `consent_state`, `os_version`.
- **Plane A — Waitlist PII** (Cloudflare D1, already live): email / name / phone /
  country / SMS-consent. Identified, pre-install.
- **Plane B — In-app analytics** (PostHog, to build): anonymous behavioral events,
  post-install. Keyed only by the anonymous code; **never joined** to Plane A.
- **On-device derivation:** durations, intervals, and session value are computed
  locally and emitted only as **buckets** (never raw seconds, never prayer
  content).

Full event taxonomy, bucketing, activation rules, retention model, and cadence
segmentation live in [`analytics-plan.md`](analytics-plan.md).

## 6. Privacy & consent (mandatory for App Store)

- **Consent posture: geo-gated (Option C).** Anonymous analytics **opt-out
  (default ON, disclosed)** for non-EU users; **EU users get an opt-in consent
  banner** (ePrivacy can require opt-in even for pseudonymous analytics). Built
  for App Store distribution, not the beta.
- **Geography:** assume primarily US, possibly EU, currently unknown — must stay
  EU-safe by default.
- **Location data:** **country-level only.** Keep country (PostHog/Cloudflare can
  derive it), **drop raw IP**.
- **Existing beta users (<10 friends):** no in-app upgrade screen; handle via
  updated privacy disclosure + TestFlight release notes.
- **ATT:** not triggered. ATT governs *cross-company* tracking; first-party
  organic referral (our link → our app) is not "tracking" under Apple's
  definition, so **no ATT prompt and no IDFA.** Re-enters scope **only if paid
  advertising is added later.**
- **Privacy policy:** rewrite **both** `docs/graces-privacy-policy.html` and
  `Graces Holy Bell/Views/PrivacyPolicyView.swift` (kept in sync) — disclose the
  waitlist PII + server + Resend + SMS consent (already true today) and the
  PostHog analytics. The current "no servers, nothing collected" text is
  inaccurate as of the Share-with-a-Friend merge.
- **App Store Connect "App Privacy":** "Data Not Collected" → Contact Info
  (waitlist), Usage Data, Identifiers (referral code), Diagnostics — most *not
  linked to identity*. `PrivacyInfo.xcprivacy`: verify reason codes; extend for
  PostHog (and Branch when added).
- **Erasure:** delete local `install_id` + purge by that ID in PostHog; SMS
  consent in Plane A independently revocable.

## 7. Accounts & constraints

- **Cloudflare** (Worker + D1 + Resend) and **Apple Developer / App Store Connect
  / TestFlight**: already set up.
- **PostHog & Branch: NOT yet created.** The AI scaffolds config and can create
  projects via API once the owner has signed up; account creation itself (email
  verification, terms, **DPA signing**) needs the owner in the loop. Use **PostHog
  EU region.**
- **Budget: stay on free tiers as long as possible** (PostHog ~1M events/mo free;
  Branch free tier; Cloudflare free limits). Design for event-volume frugality.
- **Team:** solo owner + AI session. No other developers.

## 8. Decisions log (locked)

- Analytics platform: **PostHog EU Cloud, full SDK.** **EU region confirmed** —
  permanent (no per-user/region splitting; EU covers US + EU users with no US
  downside).
- Analytics querying: **PostHog MCP** (`mcp.posthog.com/mcp`) for plain-English
  insights / dashboards / flags — read-side companion to the SDK. Install via
  `npx @posthog/wizard@latest mcp add` once the account + data exist.
- Backend: **Cloudflare** (keep existing stack).
- Deep-linking: **Branch**, first-party, no IDFA, no ATT; added near launch. No
  official Branch MCP found — drive via API/dashboard.
- Identity: **anonymous `install_id`** unifying referral code + `distinct_id`;
  **single key (not compound)**; **iPhone-generated, synced to Watch**;
  **UserDefaults persistence** (new install = new user); no auth, no accounts.
- Consent: **geo-gated** (non-EU opt-out / EU opt-in); **country geo, no IP**.
- Prayer content: **never collected** (hard rule).
- Core app: **frozen** — instrument only.

## 9. Open / future (not now)

- **North Star metric:** to be set after exploratory data arrives.
- **Paid advertising:** would reopen the ATT/IDFA decision (§6).
- **Social "watch out for me" sharing:** distant maybe; would reopen the
  auth/identity decision (§5).
- **Presentable reporting** for faith leaders / advertisers / stakeholders: later.
