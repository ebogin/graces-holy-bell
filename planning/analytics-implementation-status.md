# Analytics (Component 1) — Implementation Status & Session Handoff

> For the next session/engineer. Source of truth for the plan itself remains
> [`analytics-plan.md`](analytics-plan.md) and [`project-handoff.md`](project-handoff.md);
> this doc records **what is built, how, and what's left**.
> Last updated: 2026-06-27.

## TL;DR
Phases **1–5 are DONE and MERGED TO `main` (pushed, commit `07587e9`)**: real
PostHog SDK wired + consent-gated, full prayer lifecycle **confirmed received in
PostHog 210049**, privacy policy rewritten + published, App Store privacy answers
published (Device ID + Product Interaction + Coarse Location), and the core
analytics dashboard (id 778293) + 8 insights built. Tests green; iPhone + Watch
build clean. **Beta-prep DONE (2026-06-27):** build number → **5** (iOS + Watch in
sync), every event tagged `build_channel` (debug/release) so dev testing is
filterable, and `Secrets.plist` copied into the `main` checkout — **ready for Eric
to archive from Xcode (Release).** Only **Phase 6 (TestFlight beta)** remains, plus
the data-gated Phase 5 bespoke per-user metrics.

## Build / test commands (USE DIRECT xcodebuild)
The `xcodebuild` **MCP is unreliable on long ops** (it crashed repeatedly mid-run;
a background macOS/Xcode update also disabled the simulator once — fixed by a
reboot). Use the CLI directly:
```sh
# iPhone unit tests (the only test target; watch is compile-only)
xcodebuild test -project "Graces Holy Bell.xcodeproj" -scheme "Graces Holy Bell" \
  -destination 'platform=iOS Simulator,id=<an iOS 26.x sim UDID>'
# Watch compiles (no watch test target)
xcodebuild build -project "Graces Holy Bell.xcodeproj" \
  -scheme "Graces Holy Bell Watch App Watch App" \
  -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO
```

## Commits (this effort, newest last)
- Phase 1a/1b: `f282542`, `26209c4` — Analytics seam + install_id identity engine.
- Phase 2a–2e-ii: `55089ce`, `dd1f481`, `ee2abb0`, `798f512`, `c42293c`, `c32649c`, `726b0a1`.
- Phase 3a/3b: `1fd1ed8`, `afbd843` — consent layer + gate, Settings toggle + EU banner.
- 0→2 handoff: `2cc18a3` — real PostHog SDK.

## Architecture (what's where)
- **Seam:** `Shared/Analytics/Analytics.swift` (`protocol Analytics { capture(_:) }`).
  All app code depends only on this. `NoOpAnalytics` ships as the fallback.
- **Events/buckets/lifecycle:** `Shared/Analytics/{Events,Bucketing,Lifecycle}/`.
  `AnalyticsService` (`Shared/Analytics/AnalyticsService.swift`) is the app-facing
  coordinator — derives §2 events and forwards to the transport.
- **Consent:** `Shared/Analytics/Consent/` (state, store, `RegionConsentPolicy`,
  `ConsentGatingAnalytics`). `Graces Holy Bell/ViewModels/AnalyticsConsent.swift`
  is the observable wrapper; UI in `SettingsView` (PRIVACY toggle) +
  `Views/AnalyticsConsentBanner.swift` (first-launch EU opt-in).
- **Real transport:** `Graces Holy Bell/Utilities/PostHogTransport.swift` +
  `SecretsStore.swift` (iPhone target only — `import PostHog`).
- **Composition root:** `Graces Holy Bell/ContentView.swift` `.task` block wires
  install_id → backend (`PostHogTransport.make(installID:) ?? NoOpAnalytics()`) →
  `ConsentGatingAnalytics` → `AnalyticsService` → `vm.analytics`.

### Key decisions (do not silently undo)
- **Option A — Watch is a thin proxy.** The phone is the sole emitter. A *new*
  watch-origin prayer is counted when it first reaches the phone:
  `SessionViewModel.mergeIncoming` emits `session_started` / `prayer_logged` /
  `session_ended` for genuinely-new watch events (and for a remote Watch clear),
  tagged `device_source=watch` with the true prayer timestamps (§8 of the sync
  vision — counted once, at origin, late arrival acceptable). Echoes of events
  the phone already knows never re-emit; duplicate clears can't double-close.
  The only event emitted *by* the Watch is `prayer_log_viewed` (proxied via
  `transferUserInfo`). **Consequence:** the install_id→Watch sync is NOT
  implemented and the Phase-1 `WatchIdentityCoordinator`/`IdentityTieBreak` are
  tested-but-unexercised, reserved for a future Watch-side-emission model.
  **Known undercount edge:** watch prayers whose clear outruns them across sync
  channels (events arriving *after* their own clear was applied) are pruned
  before they can be counted — FIFO `transferUserInfo` makes this rare.
- **Consent posture:** non-EU = opt-out (default ON, disclosed); EU/EEA/UK/unknown
  = opt-in (`pending` → banner). Region from `Locale.region` (no IP/location).
  `ConsentGatingAnalytics` drops events unless `granted`. `consent_state` rides on
  events.
- **Secrets = bundled `Secrets.plist`, NOT xcconfig.** Xcode's
  `GENERATE_INFOPLIST_FILE` only honors known `INFOPLIST_KEY_*` keys, so a custom
  xcconfig key never reaches Info.plist. The plist lives in the `Graces Holy Bell/`
  synchronized group → auto-bundled, no pbxproj plumbing. `SecretsStore` reads it;
  missing/blank key → no-op transport (app still builds — e.g. fresh checkout).
- **PostHog host = `https://eu.i.posthog.com`** (ingestion), not the dashboard
  `eu.posthog.com`. Project id **210049**, EU Cloud.
- **Consent-safe PostHog init:** no `identify()` (install_id passed as `distinctId`
  per capture), `preloadFeatureFlags=false`, autocapture/screenViews off → no
  network before a gated capture. True `captureTimestamp` passed to
  `capture(..., timestamp:)` (verified the SDK supports it).

### Secrets setup (fresh checkout / another machine)
`Graces Holy Bell/Secrets.plist` is gitignored. Copy `Secrets.example.plist` to
that path and set `POSTHOG_API_KEY` (the `phc_...` project key) + `POSTHOG_HOST`
(`https://eu.i.posthog.com`). The real key was provided by Eric in chat and is in
the local (uncommitted) `Secrets.plist`.

## Live verification — DONE (2026-06-27)
Confirmed end-to-end against **real** PostHog (project 210049, EU Cloud) with the
real key. Drove the iPhone 17 sim (iOS 26.4) through a full prayer lifecycle using
the existing Maestro flows (slider swipe + stop→Clear Log); no UI-automation MCP
was available, and the xcodebuild MCP's UI tools are not enabled, so Maestro
(`~/.maestro/bin/maestro`) was the driver. One fresh-install run (`clearState`)
emitted, all received under one install_id:
`app_installed`, `app_opened`, `session_started`, `prayer_logged`×3,
`session_ended`. Properties verified correct: `consent_state=granted` and
`device_source=phone` on every event; opening prayer omits `since_last_prayer_bucket`
while idx 2–3 carry `<30m`; `session_ended` had `session_duration_bucket=<30m`,
`session_value=low` (rapid taps correctly collapsed), `prayers_in_session=3`,
`time_of_day_bucket`/`day_of_week` taken at session start. `app_version=1.42`.
- **Test data note:** this left a synthetic dev person (`F3405BD1-…`) plus earlier
  install/open/abandon events in 210049. Harmless pre-beta, but filter it out of
  Phase-5 dashboards (test-account filter / exclude these install_ids).
- **Repro:** the throwaway flow lived at `/tmp/analytics_verify_flow.yaml`
  (launch+clearState → 3× swipe `8%,82%→92%,82%` → tap `stop-button` → tap
  `Clear Log`). PostHog defaults flush ~30s, so wait before querying.

## Phase 4 — DRAFTED 2026-06-27 (pending Eric review + two decisions)
Both privacy surfaces rewritten **in sync** to disclose the PostHog analytics and
drop the now-false "no servers / nothing collected / no analytics" claims (effective
date bumped to June 27, 2026); waitlist PII + Resend + SMS were already covered and
kept:
- `docs/graces-privacy-policy.html` and `Graces Holy Bell/Views/PrivacyPolicyView.swift`
  — new "ANONYMOUS ANALYTICS" section (PostHog, EU servers, random install ID, coarse
  buckets, never prayer content, IP→approximate region, off switch + EU opt-in);
  THIRD PARTIES now names PostHog + Resend; CHILDREN reworded. Text verified identical
  across both; in-app view compiles.
- `Graces Holy Bell/PrivacyInfo.xcprivacy` — now declares **Device ID + Product
  Interaction** (Linked=false, Tracking=false, purpose Analytics). Watch xcprivacy
  **correctly unchanged** (PostHog is iPhone-target only; Watch is a thin proxy).
- `planning/app-store-privacy-answers.md` — exact App Store Connect "App Privacy"
  answers (Identifiers→Device ID, Usage Data→Product Interaction; not linked, not
  tracking, Analytics). Replaces the old "Data Not Collected" answer.
- Consent banner (`AnalyticsConsentBanner.swift`) wording already aligns with the
  new policy and links to it — no change needed.

**Decisions made (2026-06-27):**
1. **Published.** Eric approved "mirror now, as written." The updated web policy was
   mirrored to `ebogin/Boginfactory-Landing-Page` (commit `7345f67`) and the **live
   site is confirmed updated** at https://boginfactory.com/graces-privacy-policy.html.
2. **GeoIP — KEEP country + city** (Eric's decision: the geo is useful to him).
   This **supersedes** `analytics-plan.md` §7 / Phase 0 ("country-only, drop raw
   IP"); plan intent was minimization, Eric chose to keep city too. Live events
   carry `$geoip_country_name` + `$geoip_city_name` (raw `$ip` still not stored —
   fine). Disclosures updated to match: both privacy surfaces now state PostHog
   uses the IP for an approximate **country + city** (never precise/GPS), used only
   to understand where the app is used; the iPhone `PrivacyInfo.xcprivacy` and the
   App Store mapping now declare **Coarse Location** (Analytics, not linked, not
   tracking) alongside Device ID + Product Interaction. No PostHog config change.
   See `app-store-privacy-answers.md`.

**Committed:** the Phase-4 changes are committed on `claude/awesome-ellis-c6415f`
as `21b5d0a` (privacy HTML, `PrivacyPolicyView.swift`, `PrivacyInfo.xcprivacy`, the
two planning docs). Branch still unpushed, no PR. Still needs a human: App Store
Connect "App Privacy" answers entered by hand (doc drafted), shipping with the next
build submission.

## Phase 5 — STARTED 2026-06-27 (dashboard + 8 core insights live; charts fill at beta)
Built the **"Grace's Holy Bell — Core Analytics"** dashboard (id **778293**,
pinned) via the PostHog MCP, with 8 saved insights encoding the plan's metrics
(definitions are the reviewable deliverable; numbers are ~empty until beta):
- Active Users DAU/WAU/MAU (`m9WPLKvc`), Stickiness DAU÷MAU (`XQT5bbeO`),
  Weekly Retention first-prayer→return (`zcps5xMN`), Session Quality high/low
  `session_value` (`Mv9LC6zM`), Sessions by Day of Week (`PgYfxfMI`),
  Phone vs Watch `device_source` (`lilK2Vtv`), Session Duration distribution
  (`1wkuqR0i`), Lifecycle new/returning/resurrecting/dormant (`eSG3UDrJ`).
- Dashboard: https://eu.posthog.com/project/210049/dashboard/778293
- **"Active" = logged a prayer** (real engagement, not just app open).
- **Test-data caveat:** all insights are `filterTestAccounts:false`, and the
  project still contains the synthetic dev person(s) (`F3405BD1-…`). Before
  trusting absolute numbers, configure PostHog's internal/test-accounts filter to
  exclude pre-beta install_ids (or purge them), then flip insights to
  `filterTestAccounts:true`.
- **Not yet built (need real data + SQL/cohorts to validate):** per-user
  **Weekend Warrior Ratio** (% sessions Thu–Sun), **Feature-to-Core Ratio**
  (Watch-only, rolling-7d `prayer_log_viewed ÷ prayer_logger`), and the
  **cadence-population** counts (active-days per trailing 28d → Daily/Weekend/
  Occasional/Dormant). The Lifecycle + Day-of-Week insights approximate these for
  now.

## NOT done yet / next steps (in plan order)
1. **Phase 5 remainder (🤝):** the bespoke per-user ratios above, once beta data
   exists to validate them; plus the test-account filter.
2. **Phase 6 (🧍):** TestFlight beta to <10 friends; confirm clean data before the
   viral-growth plan.

## Open product items Eric may want to revisit (documented assumptions)
- 2d-i: session duration = last-prayer − start; `session_ended` time_of_day/day_of_week
  taken at session **start**; `entry_point` defaults to `.icon` (no notification/
  widget detection wired).
- `amen_alarm_fired` was **dropped** (no iOS callback for backgrounded delivery);
  `notification_tapped` renamed to **`amen_alarm_tapped`**.
- time_of_day = 8 equal 3-hour buckets; session_value = collapse taps <60s then
  high iff ≥2 distinct prayers each ≥30m apart; forgotten-timer abandon backdated to
  last-prayer+12h. (All reflected in `analytics-plan.md`.)

## Gotchas
- Don't reintroduce the xcconfig→Info.plist bridge (custom `INFOPLIST_KEY_` is
  silently ignored). xcconfig also treats `//` as a comment.
- SwiftPM pbxproj objects use placeholder UUIDs prefixed `DEADBEEF…` — intentional,
  unique, valid.
- Frozen core invariant held throughout: `AnalyticsServiceTests` /
  `AnalyticsViewModelIntegrationTests` include a no-sink guard proving app behavior
  is unchanged when analytics is absent.
