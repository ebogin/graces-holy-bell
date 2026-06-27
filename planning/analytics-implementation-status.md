# Analytics (Component 1) — Implementation Status & Session Handoff

> For the next session/engineer. Source of truth for the plan itself remains
> [`analytics-plan.md`](analytics-plan.md) and [`project-handoff.md`](project-handoff.md);
> this doc records **what is built, how, and what's left**.
> Last updated: 2026-06-27.

## TL;DR
Phases **1, 2, 3, the 0→2 real-PostHog handoff, AND live event verification are
DONE** on branch `claude/awesome-ellis-c6415f`. Real PostHog SDK is wired and
consent-gated, and the full prayer lifecycle has been **confirmed received in
PostHog project 210049** (see "Live verification — DONE" below). **126 unit tests
pass; iPhone app + Watch app both build clean.** Nothing pushed, no PR opened.
Remaining: Phase 4 (privacy policy + App Store privacy), Phase 5 (dashboards),
Phase 6 (beta).

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
- **Option A — Watch is a thin proxy.** The phone processes all Watch actions, so
  it is the sole emitter; `PhoneConnectivityManager.handleAction` tags those events
  `device_source=watch`. The only Watch-originated event is `prayer_log_viewed`
  (proxied via `transferUserInfo`). **Consequence:** the install_id→Watch sync is
  NOT implemented and the Phase-1 `WatchIdentityCoordinator`/`IdentityTieBreak` are
  tested-but-unexercised, reserved for a future Watch-side-emission model.
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
2. **GeoIP stays ON** (disclosed in the policy, not in the Apple label since IP-geo
   isn't from location services). The "Discard client IP data" option remains
   available later — see `app-store-privacy-answers.md`; if flipped, soften the IP
   paragraph in both policy surfaces.

**Still open:** the Phase-4 working-tree changes (privacy HTML, `PrivacyPolicyView.swift`,
`PrivacyInfo.xcprivacy`, the two planning docs, this doc) are **uncommitted** on
`claude/awesome-ellis-c6415f` — so the public mirror is briefly ahead of the committed
source. Commit when ready. Also: App Store Connect "App Privacy" answers still need to
be entered by hand (doc drafted), and the App Store privacy update ships with the next
build submission.

## NOT done yet / next steps (in plan order)
1. **Phase 5 (🤝):** build PostHog insights/dashboards via the PostHog MCP — weekly
   retention, cadence segments, High-Value Session Density, Feature-to-Core,
   Weekend Warrior Ratio, DAU/WAU/MAU. Needs live data first.
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
