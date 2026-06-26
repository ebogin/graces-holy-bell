# Grace's Holy Bell — Analytics Plan (Component 1 of 2)

> Status: planning. Nothing implemented yet. Last updated: 2026-06-23.
> **This is the FIRST of two plans and is built first.** It instruments the app
> and proves we get clean, trustworthy data with the beta testers *before* the
> growth work begins. The viral-growth/sharing component is a separate document:
> [`viral-growth-plan.md`](viral-growth-plan.md).
> Project context & locked decisions: [`project-handoff.md`](project-handoff.md).

## Goal

Understand how people actually use the app — **maximally instrument behavior,
minimally collect identity**. Anonymous, GDPR-compliant, App Store–clean.

Headline questions:

- How often do full prayer sessions happen? (daily / weekend / occasional)
- How many prayers per session, and how long is each prayer?
- What is a *genuinely activated* user vs. a curious explorer?
- User base: installs (phone + watch), active users, cadence segments.
- Retention across cyclical, weekend-heavy lifestyle intervals.

(Viral K-factor and referral attribution are out of scope here — see the
viral-growth plan.)

## Platform

- **PostHog (EU Cloud, full iOS SDK) = product analytics.** Out-of-the-box
  funnels, retention, cohorts, Lifecycle & Stickiness — no SQL, no hand-built
  dashboards. **EU region is permanent** (one project = one region; EU covers US +
  EU users with no US downside). Signed DPA + anonymous-only `distinct_id` covers
  GDPR.
- **PostHog MCP** (`mcp.posthog.com/mcp`) = the read/manage companion for
  plain-English insights, dashboards, and flags. Install via
  `npx @posthog/wizard@latest mcp add` once the account + data exist.
- Analytics talks to PostHog directly via the SDK. (Cloudflare runs the waitlist /
  viral backend — that lives in the viral-growth plan.)

---

## 1. Identity & architecture

- **One anonymous identity:** `install_id` = PostHog `distinct_id` (and, for the
  viral plan, the referral code). Random, no PII. The retention/cohort key.
  - **Shared across devices:** generated on iPhone (canonical). The Watch never
    mints its own *transmitted* identity — see **Watch transport & event timing**
    below — so one person is never counted twice.
  - **Persistence: UserDefaults** (not Keychain) — delete-and-reinstall yields a
    new ID ("new install = new user"). Chosen for simplicity + honest anonymity.
  - **Single key, not compound.** Everything else rides as PostHog *person/event
    properties* (see below).
- **Two data planes, bridged only by that code:**
  - **Plane A — Waitlist PII** (Cloudflare D1, already live): email / name /
    phone / country / SMS-consent. Identified, pre-install. (Owned by the viral
    plan.)
  - **Plane B — In-app analytics** (PostHog, this plan): anonymous behavioral
    events, post-install.
- **Wall between planes:** Plane B is keyed only by the anonymous code and is
  **never joined** to waitlist email/phone.
- **On-device derivation:** prayer logs already live on-device, so durations,
  intervals, and session classification are computed locally and emitted only as
  **buckets** — PostHog never receives raw seconds or prayer content.
- **Client abstraction:** thin `Analytics` protocol in `Shared/`, no-op by
  default, swappable; PostHog SDK behind it. View code never touches the SDK.

### Watch transport & event timing

- **iPhone is the canonical `install_id` generator.** The Watch app is a dependent
  companion, so the iPhone app always exists (it may simply not have launched yet).
- **The Watch never transmits an event until it holds the canonical
  `install_id`.** Until then it holds events in a local **pending queue**. On a
  Watch-first cold start it requests the ID from the phone over WCSession; if
  neither device has one yet, a **deterministic tie-break** decides (iPhone-minted
  wins; if both mint one, earliest-timestamp / lexicographically-smaller wins and
  the other device adopts it). Because nothing is sent before the ID resolves,
  **no PostHog merge/alias is ever needed and there are no phantom users** — queued
  events are simply re-tagged with the canonical ID.
- **All Watch events proxy through the phone's PostHog SDK** (no separate watchOS
  SDK instance): one queue, one config, one consent gate. Delivery uses WCSession
  `transferUserInfo`, which the OS persists and delivers on reconnect — so
  phone-less Watch sessions are **delayed, never lost** (acceptable: analytics is
  not real-time).
- **Origin device is preserved.** Every event sets `device_source` to the
  **originating** device (`watch`) *before* queuing; the phone is only the
  transport and must **not** overwrite it to `phone`. This is what lets PostHog
  cleanly separate watch-based from iPhone-based usage.
- **True event time is preserved.** Each proxied (and each next-launch-synthesized)
  event carries its real capture timestamp, sent to PostHog via the SDK
  **`timestamp` override**, so it lands at the correct chronological point — not at
  sync or re-open time. See *Synthesized / backdated events* in §2.

## 2. Event taxonomy (Plane B — anonymous)

Every event carries these **cross-device context properties**:

- `device_source` — `phone` | `watch`.
- `amen_alarm_status` — `phone` | `watch` | `both` | `off`.
- `amen_alarm_duration_setting` — chosen interval (30m / 45m / 1h / 1h15 / 1h30 /
  1h45 / 2h).

Person/event properties also include: `first_seen` / `install_date`,
`app_version`, `os_version`, `country` (geo, no IP), `consent_state`.

### Events

| Event | Fires when | Event-specific properties |
|---|---|---|
| `app_installed` | First iPhone launch (sets `first_seen`) | `app_version`, `install_date` (`referrer` is attached by the viral plan, when present) |
| `watch_app_installed` | Watch app first seen (multi-device distribution) | `app_version` |
| `app_opened` | Every foreground | `entry_point` (icon / notification / widget), `days_since_install` |
| `session_started` | Prayer session begins | `entry_point`, `time_of_day_bucket`, `day_of_week` |
| `prayer_logged` | Each prayer (Amen) within a session | `prayer_index_in_session` (incrementing count), `since_last_prayer_bucket` |
| `session_ended` | User completes/ends a session normally | `prayers_in_session`, `session_value` (high / low), `session_duration_bucket`, `time_of_day_bucket`, `day_of_week` |
| `session_abandoned` | Session left incomplete, **or** auto-fired when a prayer timer runs past **12h** | `prayers_so_far`, `reason` (`user_exit` \| `forgotten_timer`) |
| `amen_alarm_set` | Alarm enabled/changed | (alarm props above carry the detail) |
| `amen_alarm_fired` | Local notification delivered | `time_of_day_bucket` |
| `notification_tapped` | App opened from the alarm | `time_of_day_bucket` |
| `prayer_log_viewed` | Log screen opened — **Watch only** (on iPhone the log is always visible on the main timer page, so there is no discrete view to track) | — (always `device_source = watch`) |

**Forgotten-timer rule:** if a prayer timer runs continuously past 12 hours, fire
`session_abandoned` with `reason = forgotten_timer` so it is *not* counted as
churn or a UX failure — a user who walked away without ending the timer. The app
cannot fire this while suspended/force-quit, so it is **synthesized on the next
launch** and backdated — see *Synthesized / backdated events* below.

**Session lifecycle — no double-close:** a session terminates exactly once. If a
session already ended via `session_abandoned` (e.g. a forgotten timer), the next
prayer days/weeks later starts a **fresh** `session_started` — it must **not**
emit a retroactive `session_ended` first. Guard against a `session_ended` fired
immediately before a `session_started`: that stale session already ended at its
`session_abandoned` event, and its duration is measured to that abandon point.

**Synthesized / backdated events:** any event that can only be *computed at next
launch* must be **backdated to its true time** via the PostHog `timestamp`
override, not stamped at re-open/sync time. Two cases: (1) the forgotten-timer
`session_abandoned` lands at **session start + 12h**; (2) late-delivered Watch
events land at their **original capture time**. Without this, the user's PostHog
timeline is distorted and retention/interval math breaks.

Pruned: `settings_opened`, pure navigation / scroll / impression noise, and
`privacy_policy_viewed`. (Share/referral events live in the viral-growth plan.)

## 3. Bucketing (GDPR-safe, derived on-device)

Durations/intervals are computed locally and emitted only as buckets — never raw
seconds, never prayer content. Buckets align to the **Amen Alarm interval
boundaries** so prayer length, inter-prayer gap, and alarm cadence are directly
comparable:

- **`session_duration_bucket` / `since_last_prayer_bucket`:** 15-minute brackets
  out to 4 hours, final `4h+` catch-all —
  `<30m` · `30–45m` · `45–60m` · `1h–1h15` · `1h15–1h30` · `1h30–1h45` ·
  `1h45–2h` · `2h–2h15` · `2h15–2h30` · `2h30–2h45` · `2h45–3h` · `3h–3h15` ·
  `3h15–3h30` · `3h30–3h45` · `3h45–4h` · `4h+`
- **`time_of_day_bucket`:** eight equal 3-hour windows (local time), so every
  part of the day — including overnight — gets equal resolution:
  `late-night` (00–03) · `early-morning` (03–06) · `morning` (06–09) ·
  `late-morning` (09–12) · `midday` (12–15) · `afternoon` (15–18) ·
  `evening` (18–21) · `night` (21–24)
- **`day_of_week`:** used to derive weekend vs. weekday behavior

## 4. Activation & engagement quality

### High-Value Session Density
Rapid taps (<60s apart) are first **collapsed into one** "real" prayer, so an
accidental double/triple tap (e.g. a slow display) cannot drag a session down.
Then:
- **Low-Value / Explorer session:** 1 distinct prayer, or multiple prayers in
  rapid immediate succession.
- **High-Value / Activated session:** **2+ distinct prayers, each ≥30 minutes
  apart** — proving the app is woven into the user's day, not just being tested.

`session_value` (`high` | `low`) is computed on-device at `session_ended`; the
crucial signal for **W1 cohort quality**.

### Feature-to-Core Ratio (Watch-only)
The log is a discrete, intentional screen **only on the Watch** (on iPhone it's
always visible on the timer page), so this is a **Watch-specific** metric: among
users who pray on the Watch, what share deliberately check their history
(`prayer_log_viewed`) vs. only execute raw prayer actions.

One event powers **three lenses** (all analysis-time in PostHog — no extra
instrumentation), tracked together so the ratio doesn't drift toward 100% over a
user's lifetime:
- **Same-session** — did they open the log in the same Watch sitting as a prayer?
- **24-hour** — within 24h of a prayer.
- **Rolling 7-day** *(primary)* — log-viewers ÷ prayer-loggers over the trailing
  7 days, matching the weekly-bracketed retention frame.

## 5. Retention — weekly, bracketed (replaces D1/D7/D30/D90)

The app is cyclical and weekend-heavy, so day-checkpoint retention generates false
negatives. Use **unbounded, weekly-bracketed** cohorts:

- **W1** — active during the week (incl. weekend) after install.
- **W4 / M1** — active during week 4 / month 1.
- **W12 / M3** — sustained engagement at week 12 / month 3.

"Active in week N" counts a return at *any point* that week. PostHog **Retention**
+ **Lifecycle** insights produce these directly.

## 6. User-base cadence segmentation

Classify each user by cadence over a rolling 28-day window and count the
populations:

| Segment | Definition |
|---|---|
| **Daily / Habitual** | Active most days; sessions spread across the week |
| **Weekend Warrior** | Activity concentrated Thu–Sun, sparse on weekdays |
| **Occasional** | Active ~1–3 days/month |
| **Dormant** | Previously active, now silent |

Driven by (both native PostHog): (1) **active-days / active-weekends per trailing
28 days** → segment buckets; (2) **Weekend Warrior Ratio** — per user, % of
sessions landing Thu–Sun. Plus **DAU / WAU / MAU**, **Stickiness (DAU÷MAU)**, and
a **phone vs. watch** split from `device_source`.

## 7. What is NOT collected

- **Never in Plane B:** prayer content, name, email, contacts, location, IDFA,
  raw second-level durations.
- **Bucketed, on-device-derived** timing only (§3).
- **Country-level geo only** — keep country, **drop raw IP**.
- **Erasure:** delete local `install_id` + purge by that ID in PostHog satisfies
  GDPR right-to-erasure.

## 8. Privacy & App Store (mandatory for distribution)

- **Consent: geo-gated.** Anonymous analytics **opt-out (default ON, disclosed)**
  for non-EU; **EU users get an opt-in consent banner**. A Settings toggle gates
  transmission; `consent_state` rides as a property.
- **Beta testers (<10 friends):** no in-app upgrade screen; handle via updated
  privacy disclosure + TestFlight release notes. (Geo-gated consent ships for
  App Store users.)
- **Privacy policy:** rewrite **both** `docs/graces-privacy-policy.html` and
  `Graces Holy Bell/Views/PrivacyPolicyView.swift` (kept in sync). Disclose the
  waitlist PII + server + Resend + SMS consent (already true) and the PostHog
  analytics. The current "no servers, nothing collected" text is inaccurate.
- **App Store Connect "App Privacy":** "Data Not Collected" → Usage Data,
  Diagnostics, Identifiers — *not linked to identity* in Plane B. (Contact Info
  comes from the waitlist; "Data Used to Track You" only if Branch/ads are added —
  viral plan.)
- **`PrivacyInfo.xcprivacy`:** verify reason codes; extend for the PostHog SDK.

## 9. Phasing & task ownership (this plan, built first)

Tasks are one of two kinds, intended to run in **two parallel chat windows** so
the coding agent isn't gated on human turnaround:

- 🤖 **Agent** — autonomous coding (the agent build chat).
- 🧍 **Human** — owner actions an AI must walk through step-by-step (the setup
  chat): account creation, signing legal terms, anything in a vendor/Apple web UI,
  physical-device/TestFlight actions.
- 🤝 **Handoff** — an agent deliverable the human consumes, or vice-versa.

### Frozen-code boundary (read first)
"Core app frozen" means **no behavior, logic, UI, or WatchConnectivity changes**.
Adding **additive, side-effect-free analytics hook calls** through the `Analytics`
protocol at the right points is *expected and allowed* — that is the
instrumentation. Hooks must not alter control flow, ordering, or output. If a hook
seems to require a logic change, stop and raise it rather than modifying frozen
code.

### Phases

| # | Phase | Owner | Notes |
|---|---|---|---|
| 0 | **PostHog EU account** | 🧍 | Create EU project, sign DPA, generate keys; configure project (autocapture off, disable IP/geo→country only). Output: keys → §0 handoff. |
| 1 | **Foundation (no-op)** | 🤖 | `install_id` (UserDefaults, iPhone→Watch sync, pending queue + tie-break); `Analytics` protocol in `Shared/`; **mock/no-op transport**. Builds + tests green with **no real keys** — does not block on Phase 0. |
| 2 | **Core instrumentation** | 🤖 | §2 events + cross-device props across iOS + watchOS; Watch→phone proxy + `device_source` preservation + `timestamp` overrides; §3 bucketing; `session_value`; 12h synth + no-double-close. Verify on iPhone + Watch sim. |
| 0→2 | **Wire real PostHog SDK** | 🤝 | Agent swaps the mock transport for the PostHog SDK once the human delivers keys (Phase 0). Keys injected via xcconfig/secrets — **never committed**. |
| 3 | **Consent & privacy gating** | 🤖 | Geo-gated consent, Settings toggle gates transmission, `consent_state`, country-geo-without-IP. |
| 4 | **Privacy policy + App Store privacy** | 🤝 | Agent rewrites both policy surfaces (mirror web policy to the public landing-page repo) + `PrivacyInfo.xcprivacy` + produces the Connect answer mapping; 🧍 human enters answers in App Store Connect. |
| 5 | **Dashboards (PostHog MCP)** | 🤝 | Agent builds insights via PostHog MCP (needs MCP installed in Phase 0); 🧍 human reviews. Weekly retention, cadence segments, High-Value Session Density, Feature-to-Core, Weekend Warrior Ratio, DAU/WAU/MAU. |
| 6 | **Beta rollout** | 🧍 | Build → TestFlight → <10 testers; updated privacy disclosure + release notes. Confirm clean data **before** starting the viral-growth plan. |

### Parallel-execution model
The two chats meet at the **interface contract**: the agent (Phase 1) builds the
whole abstraction + instrumentation + tests against a **mock transport**, so it can
proceed immediately without waiting on the human. In parallel the human (Phase 0)
provisions PostHog + MCP + (later) Connect/TestFlight. They converge at the
**0→2 handoff**, where the agent swaps the mock for the real PostHog SDK using the
keys the human produced. The only hard cross-dependencies: real-key wiring (needs
Phase 0), dashboards (need the MCP + live data), Connect answers and TestFlight
(human-only).

> Prayer *content* is out of scope — logs stay 100% on-device, never collected,
> shared, or aggregated.
