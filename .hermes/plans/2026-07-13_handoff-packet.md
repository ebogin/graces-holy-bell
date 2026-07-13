# Grace's Holy Bell — Release Handoff Packet

> **Date:** 2026-07-13
> **Audited commit:** `d9d756f9ef27d8c491272402193abc5407e434d7`
> **Audited branch:** `main` (matches `origin/main` exactly)
> **Checked out (not audited):** `release/1.51` — divergent, stale, DO NOT use
> **Current version/build:** `1.5 (3)` (iPhone, Watch, Widget all consistent)
> **Verdict:** Ready for continued TestFlight development **| NOT ready for App Review**

---

## Contents

1. [State of the release](#1-state-of-the-release)
2. [What has been verified](#2-what-has-been-verified)
3. [Blocker summary](#3-blocker-summary)
4. [Handoff A — Delay PostHog SDK setup until consent (code change)](#4-handoff-a--delay-posthog-sdk-setup-until-consent-code-change)
5. [Handoff B — Update privacy disclosures for Other Usage Data (compliance/docs)](#5-handoff-b--update-privacy-disclosures-for-other-usage-data-compliancedocs)
6. [Acceptance testing plan](#6-acceptance-testing-plan)
7. [Key reference info](#7-key-reference-info)
8. [Project architecture reference](#8-project-architecture-reference)

---

## 1. State of the release

### What `main` is

| Property | Value |
|----------|-------|
| Commit | `d9d756f9ef27d8c491272402193abc5407e434d7` |
| Date | 2026-07-11 |
| Subject | Add grace-welcome skill for Claude cloud containers |
| iOS version | 1.5 (3) |
| Watch version | 1.5 (3) |
| Widget version | 1.5 (3) |
| Deployment target | iOS 26.2 / watchOS 26.2 |
| Project | `Boginfactory.Graces-Holy-Bell` |
| Team | `5GWLV9DSB5` (Boginfactory Consulting, LLC) |
| Xcode | 26.6 (17F113) |

### The `release/1.51` branch is stale and unsafe

The currently checked-out branch `release/1.51` is:

- One commit ahead of its pre-main parent (just a version bump to `1.51 (2)`)
- **Seven commits behind main** — missing the welcome message feature, remote config, and related tests/Worker changes
- Has removed files (`RemoteConfig.swift`, `WelcomeMessageView.swift`, Worker app-config code) that `main` depends on

**Before shipping:** cut a NEW release branch from current `main`. Do not use the existing `release/1.51`.

### Archived successfully

A generic-device Release archive was created with isolated Derived Data and passed:

- Deep code-signing verification
- All embedded bundles correct (iPhone, Watch, Widget)
- Production `Secrets.plist` present with nonempty PostHog credentials
- `silence.caf` and custom font included
- All privacy manifests embedded

The archive used **Apple Development** signing (with `get-task-allow`). App Store distribution export and TestFlight processing have NOT been verified. Build 3 may already exist in App Store Connect — you may need build 4 or higher.

---

## 2. What has been verified

| Area | Status | Evidence |
|------|--------|----------|
| iOS XCTest suite | ✅ 223 passed, 0 failed | `proc_48b1d628f656` on iPhone 17 + Watch Ultra 3 sim |
| Worker tests | ✅ 35/35 passed | `proc_c00ba1ea58fc` |
| Release sim build | ✅ BUILD SUCCEEDED | `proc_6e0cf0fc82cf` |
| Device archive | ✅ ARCHIVE SUCCEEDED, valid signing | Second attempt with isolated Derived Data |
| Privacy manifests | ✅ Three manifests in archive: app, PostHog SDK, PHPLCrashReporter | Verified via `find ... -name PrivacyInfo.xcprivacy` |
| Public endpoints | ✅ All HTTP 200: landing, policy, waitlist, thanks, app-config | `curl` probes |
| PostHog live config | ✅ errorTracking disabled, sessionRecording disabled, hasFeatureFlags false | Direct API call with project token |
| Secrets in archive | ✅ `Secrets.plist` present with nonempty key | Verified in signed archive bundle |

### What has NOT been verified

- [ ] App Store distribution export and validation
- [ ] TestFlight acceptance (install from processed TestFlight build, not local Xcode)
- [ ] Physical paired iPhone+Watch acceptance (all sync, notification, alarm tests)
- [ ] VoiceOver acceptance (the custom prayer slider likely blocks this)
- [ ] V1 and V2 store upgrade acceptance
- [ ] EU consent + network-capture verification
- [ ] App Store Connect privacy answers, metadata, screenshots, age rating, export compliance

---

## 3. Blocker summary

### 🟥 Pre-consent PostHog network request (high-priority, low-risk)

**What:** PostHog SDK 3.62.0's `setup()` makes a GET request to `eu-assets.i.posthog.com/array/<token>/config` even with `preloadFeatureFlags = false`. The code comment says this doesn't happen, but it does.

**Why it matters:** Contradicts the stated design that nothing contacts PostHog before consent. The request contains no event payload or user identifier, but does expose the device's IP.

**Fix:** See [Handoff A](#4-handoff-a--delay-posthog-sdk-setup-until-consent-code-change).

### 🟨 Other Usage Data not in App Store Connect answers (moderate priority)

**What:** PostHog's bundled `PostHog_PostHog.bundle/PrivacyInfo.xcprivacy` declares "Other Usage Data" (standard OS/device/app version event context). Your App Store Connect answers don't list this.

**Why it matters:** Apple's automated privacy report will see the SDK manifest and may flag the mismatch. The in-app and web policies already mention "your app, device, and operating-system version" which covers it textually.

**Fix:** See [Handoff B](#5-handoff-b--update-privacy-disclosures-for-other-usage-data-compliancedocs).

### 🟨 VoiceOver likely cannot operate the prayer slider (moderate-to-high priority)

**What:** Both iPhone and Watch prayer sliders use `DragGesture` only. No accessibility action, adjustable action, meaningful label, or alternative activation.

**Why it matters:** VoiceOver users likely cannot start or log a prayer — the app's central function. This should be treated as at least S1 (critical) if confirmed.

**Not blocked by:** Source inspection alone. **Must be physically tested** with VoiceOver to confirm. If it works (unlikely from code review), this is not a blocker.

### 🟨 Missing explicit `false` on unused PostHog features (lower priority, good hygiene)

**What:** Several PostHog features default to `true` (surveys) or have mutable defaults that could change in a future SDK version.

**Fix:** In `PostHogTransport.swift` init, add:
```swift
config.surveys = false
config.sessionReplay = false
config.captureElementInteractions = false
```

These can be added alongside the Handoff A code changes.

### 🟨 Deployment target 26.2 severely restricts availability (product decision, not blocker)

iOS 26.2 and watchOS 26.2 minimums exclude every device not running those exact OS versions. This needs an explicit go/no-go decision.

---

## 4. Handoff A — Delay PostHog SDK setup until consent (code change)

> **For an engineer AI with Xcode access.** This is a code-change task requiring Swift/iOS knowledge.

### Context

Grace's Holy Bell currently initializes PostHogSDK during ContentView setup, before the consent gate checks whether the user has allowed analytics. PostHog 3.62.0 performs a remote-config network request during `setup()` even when `preloadFeatureFlags = false`. This means a network request to PostHog's servers occurs before the EU/EEA/UK consent screen has been answered, contradicting the app's stated privacy design.

### Files to modify

#### Create: `Shared/Analytics/SwappableAnalytics.swift`

A thread-safe wrapper over the `Analytics` protocol that allows swapping the underlying transport at runtime. This is needed because `AnalyticsService` stores its transport as `private let transport: Analytics` (immutable).

```swift
import Foundation

/// Analytics decorator whose underlying transport can be swapped at runtime.
/// Start with NoOpAnalytics, then swap to PostHogTransport once consent is granted.
/// All `capture` calls delegate to whichever transport is currently active.
final class SwappableAnalytics: Analytics {
    private let lock = NSLock()
    private var wrapped: Analytics

    init(initial: Analytics) {
        self.wrapped = initial
    }

    func swap(to new: Analytics) {
        lock.withLock { wrapped = new }
    }

    func capture(_ event: AnalyticsEvent) {
        lock.withLock { wrapped.capture(event) }
    }
}
```

Add this file to the Xcode project's Shared target so both iPhone and test code can see it.

#### Modify: `Graces Holy Bell/ContentView.swift`

**Current flow (lines 97–157):**
1. Resolves installID
2. Calls `PostHogTransport.make(installID:)` → calls `PostHogSDK.shared.setup(config)` → **network request**
3. Wraps in ConsentGatingAnalytics
4. Creates AnalyticsService

**Required new flow:**
1. Create a `SwappableAnalytics(initial: NoOpAnalytics())` immediately
2. Wrap IT in `ConsentGatingAnalytics` (the consent gate still drops events before consent)
3. Create AnalyticsService with that chain
4. Observe `consent.state` — when it becomes `.granted`, resolve installID, call `PostHogTransport.make(installID:)`, and `swappable.swap(to: posthogTransport)`
5. Add `PostHogTransport` to the observation so other unused features are explicitly disabled (surveys, sessionReplay, element interactions)

**Key reference: `PostHogTransport.swift` lines 26–34:**
```swift
let config = PostHogConfig(apiKey: *** host: secrets.host)
config.captureApplicationLifecycleEvents = false
config.captureScreenViews = false
config.preloadFeatureFlags = false
// ADD these:
config.surveys = false
config.sessionReplay = false
config.captureElementInteractions = false
```

**Consent observation approach:**

Use `AnalyticsConsent.state` (an `@Observable` property). The geo-gated default already applies the correct initial state:

- Non-EU users: starts `.granted` → PostHog setup happens on the first observation change
- EU users: starts `.pending` → PostHog setup happens when user taps Allow

```swift
.onChange(of: consent.state) { _, newState in
    if newState == .granted {
        let installID = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()
        if let posthog = PostHogTransport.make(installID: installID) {
            swappableAnalytics.swap(to: posthog)
        }
    }
}
```

The `SwappableAnalytics` variable needs to be a `@State` so it lives across the view's lifetime and is accessible from the `.onChange` closure.

### Verification

1. Build and run in simulator.
2. Add a breakpoint or `os_log` in `PostHogSDK.shared.setup(config)` — confirm it is **NOT** called on launch.
3. For a non-EU locale (e.g., `en_US`), confirm setup IS called shortly after launch (consent defaults to granted).
4. For an EU locale, confirm setup is **NOT** called until you tap "Allow" on the consent banner.
5. Run the full test suite: `xcodebuild test`.

---

## 5. Handoff B — Update privacy disclosures for Other Usage Data (compliance/docs)

> **For a docs/compliance agent.** This task updates the privacy disclosure documents to account for PostHog's bundled manifest declaring "Other Usage Data."

### Background

The app's signed archive contains PostHog's bundled `PostHog_PostHog.bundle/PrivacyInfo.xcprivacy`, which declares:

- Product Interaction (already disclosed)
- **Other Usage Data** (NOT currently disclosed)

"Other Usage Data" in this context covers the default device/app/OS properties PostHog attaches to every analytics event (OS version, app version, device model, SDK version, screen dimensions, etc.). These are standard analytics context fields, not PII. The app does not proactively collect any additional "other" data — this is simply what the SDK includes as event metadata.

### Files to modify

#### 1. `planning/app-store-privacy-answers.md`

Add "Other Usage Data" to the table in the TL;DR section. After the existing row for `Coarse Location`, insert:

```markdown
| **Other Usage Data** | Usage Data | No | No | Analytics |
```

In the Step-by-step section, add after step 5:

```markdown
> 6. **Do you collect "Other Usage Data"?** → **Yes.**
>    - *Category:* **Usage Data → Other Usage Data**
>    - *Used to track you?* **No.**
>    - *Linked to your identity?* **No** (it's bundled with the anonymous event, not tied to a named user).
>    - *Purpose:* **Analytics.**
>    - *Why?* PostHog's SDK automatically attaches operating system version, app version, device model, screen dimensions, and SDK build info to every analytics event as default context. These are standard analytics metadata — not separate tracked dimensions.
```

Also update the Loose Ends section to explain this was reconciled.

#### 2. `docs/graces-privacy-policy.html`

Check whether the "ANONYMOUS ANALYTICS" section already covers "your app, device, and operating-system version." If it does, the prose likely already covers what PostHog means by "Other Usage Data" and no change may be needed. If not, add a clarifying sentence.

#### 3. `Graces Holy Bell/Views/PrivacyPolicyView.swift`

Same check as the HTML policy. The in-app policy should match the web policy.

#### 4. App Store Connect (manual — cannot be scripted)

Open App Store Connect → your app → App Privacy → edit answers. In the **Usage Data** category, verify "Other Usage Data" is either:

- **Already listed** (if Apple's aggregated report automatically included it from the SDK manifest), in which case confirm the answers match (Not Linked, Not Tracking, Analytics Purpose).
- **Missing**, in which case click **Add** → **Usage Data** → **Other Usage Data** and set the answers: Not Linked, Not Tracking, Analytics Purpose.

### Verification

| Check | How |
|---|---|
| Policy prose covers standard device/app/OS event metadata | Read both policy files |
| App Store Connect answers include Other Usage Data | Log in and inspect |
| Privacy manifest matches stated answers | Compare archive manifests vs Connect answers |
| No other PostHog-transitive types are missing | Compare every row in every `PrivacyInfo.xcprivacy` in the archive against Connect answers |

---

## 6. Acceptance testing plan

A detailed 55-test acceptance plan has been saved at:

**`.hermes/plans/2026-07-13_105337-release-acceptance-testing.md`**

The plan covers:

| Section | Tests | Area |
|---------|-------|------|
| Smoke | A01–A05 | Clean launch, start/log/stop, settings, Watch sync, links |
| Core | A06–A10 | Accidental-action, long timer, editing, end-session |
| Persistence | A11–A13 | V1 and V2 upgrade, durability, low-storage |
| Sync matrix | A14–A20 | Offline, conflict, clear propagation, install states |
| Alarm | A21–A25 | Permission, deny, phone/watch/both, offline, AMEN state |
| Live Activity | A26–A29 | Lifecycle, toggle, reboot, widget |
| Privacy | A30–A34 | EU consent, non-EU, payload inspection, SDK controls, reconciliation |
| Remote config | A35–A38 | Normal, offline, malformed, rollback |
| Sharing | A39–A43 | Phone QR, Watch QR, signup, redirect, admin |
| Accessibility | A44–A49 | VoiceOver, Dynamic Type, Reduce Motion, contrast, small screens |
| Exploratory | A50–A51 | 30-min session, overnight soak |
| Submission | A52–A55 | Metadata, screenshots, privacy, final build |

### Recommended execution order for a solo developer

| Pass | Duration | Tests | Stop rule |
|------|----------|-------|-----------|
| 1 | 15 min | A01–A05 (smoke) | Stop if any fail |
| 2 | 60–90 min | A06–A13 (core + upgrade) | — |
| 3 | 60–90 min | A14–A20 (Watch sync) | — |
| 4 | 60 min + wait times | A21–A29 (alarm + Live Activity) | Physical devices required |
| 5 | 60 min | A30–A43 (privacy, remote, sharing) | PostHog setup fix must be done first |
| 6 | 45 min | A44–A49 (accessibility) | — |
| 7 | 30 min + overnight | A50–A51 | — |
| 8 | 30 min | A52–A55 + sign-off | Final gate |

### Defect severity

| Level | Meaning | Examples | Release rule |
|-------|---------|---------|--------------|
| **S0** | Blocker | Crash, data loss, privacy violation, wrong backend, rejected archive | Must fix |
| **S1** | Critical | Cannot start/log/stop; lost/duplicate prayers; broken sync or alarm; VoiceOver cannot use slider | Must fix |
| **S2** | Major | Sharing fails; remote welcome broken; Live Activity stale | Fix or explicitly defer with rationale |
| **S3** | Minor | Spacing, harmless wording | May ship if documented |

### Release exit criteria

- Zero open S0 or S1 defects
- Every mandatory test passes on the final TestFlight build
- No code/config changes after final acceptance run
- App Store Connect privacy answers, policy, screenshots, version/build, URLs, and archive all describe the same product

---

## 7. Key reference info

### Version/build anchoring

| Target | Bundle ID | Version | Build |
|--------|-----------|---------|-------|
| iPhone app | `Boginfactory.Graces-Holy-Bell` | 1.5 | 3 |
| Watch app | `Boginfactory.Graces-Holy-Bell.watchkitapp` | 1.5 | 3 |
| Widget ext | `Boginfactory.Graces-Holy-Bell.GraceTimerWidget` | 1.5 | 3 |

### Public endpoints

| Endpoint | URL | Status |
|----------|-----|--------|
| Landing page | `https://boginfactory.com/grace-holy-bell.html` | HTTP 200 |
| Privacy policy | `https://boginfactory.com/graces-privacy-policy.html` | HTTP 200 |
| Waitlist    | `https://boginfactory.com/grace-waitlist.html` | HTTP 200 |
| Thank-you   | `https://boginfactory.com/grace-waitlist-thanks.html` | HTTP 200 |
| Contact     | `https://boginfactory.com/grace-contact.html` | HTTP 200 |
| Remote config | `https://boginfactory.com/app-config` | HTTP 200, JSON |
| Worker config | `https://grace-waitlist.grace-waitlist.workers.dev/app-config` | HTTP 200, JSON |

### Production PostHog

- Project ID: `210049`
- Host: `https://eu.i.posthog.com` (EU cloud)
- API key: stored in gitignored `Secrets.plist` (present in archive)
- Dashboard: `https://eu.posthog.com/project/210049/dashboard/778293`
- Live config: errorTracking OFF, sessionRecording OFF, hasFeatureFlags OFF

### Branch relationships

```
main (d9d756f) ← audit target → origin/main
  |
  ├── claude/version-bump-v1-52-0f61b3  (build 1.52 aboard a different path)
  ├── release/1.51 (STALE — diverged, DO NOT USE)
  └── release/1.5 (does not exist yet — needs to be created from main)
```

### Warning: Feature flags

`FeatureFlags.prayerHistoryEnabled = false` (intentional — history view has known display bugs). Background archiving still runs but the Settings row is hidden. Do not enable for release.

### Warning: 30-second Alarm duration

A `30 sec (test)` alarm option exists. Decide whether to ship it (rename it) or remove it for production.

### Warning: Screenshots

Observed in `App Store Submission/`:
- iPhone: `1320×2868` (1 screenshot only)
- Watch: `422×514` (2 screenshots)

These are untracked. Update to match the shipping build. Apple commonly requires at least 1 iPhone set; a single screenshot is weak marketing but may meet minimum requirements.

### Existing planning docs in repo

| File | Content |
|------|---------|
| `planning/analytics-implementation-status.md` | Current state of analytics project |
| `planning/analytics-plan.md` | Original analytics implementation plan |
| `planning/app-store-privacy-answers.md` | **Needs update** — App Store Connect privacy mapping |
| `planning/persistence-migration-bug-plan.md` | 1.41→1.42 migration fix history |
| `planning/project-handoff.md` | High-level project context |
| `planning/referral-click-tracking-spec.md` | Referral tracking design |
| `planning/viral-growth-plan.md` | Growth/post-launch plan |
| `planning/watch-sync-refactor-execution-plan.md` | Watch sync architecture |
| `planning/watch-sync-refactor-vision.md` | Watch sync design vision |
| `planning/watch-qr-share-feature.md` | Watch QR sharing design |
| `planning/ship-readiness-audit-handoff.md` | Prior audit (July 7) — mostly superseded by this packet |

---

## 8. Project architecture reference

### Key files

| File | Purpose |
|------|---------|
| `Graces Holy Bell/Graces_Holy_BellApp.swift` | App entry point, SwiftData container setup, font registration |
| `Graces Holy Bell/ContentView.swift` | Root view routing between idle/active, **where PostHog is initialized** |
| `Graces Holy Bell/ViewModels/AnalyticsConsent.swift` | Observable consent state (granted/denied/pending) |
| `Graces Holy Bell/Utilities/PostHogTransport.swift` | Real PostHog transport — **where setup() is called** |
| `Graces Holy Bell/Utilities/SecretsStore.swift` | Reads gitignored Secrets.plist for PostHog credentials |
| `Shared/Analytics/Consent/ConsentGatingAnalytics.swift` | Gating layer: drops events when consent not granted |
| `Shared/Analytics/AnalyticsService.swift` | App-facing analytics coordinator |
| `Shared/Analytics/Analytics.swift` | Protocol defining the analytics seam (single `capture` method) |
| `Shared/Analytics/NoOpAnalytics.swift` | No-op transport for dev builds without secrets |
| `Shared/SyncEngine.swift` | Stable-event-ordered sync between phone and Watch |
| `Shared/SyncedState.swift` | SyncSnapshot model, merge, tombstones, clear epochs |
| `Graces Holy Bell/Utilities/AmenAlarmManager.swift` | Local notification Amen Alarm scheduling |
| `Graces Holy Bell/Connectivity/PhoneConnectivityManager.swift` | iPhone side of WatchConnectivity |
| `Graces Holy Bell Watch App Watch App/Connectivity/WatchConnectivityManager.swift` | Watch side of WatchConnectivity |
| `Graces Holy Bell/RemoteConfig.swift` | Remote welcome-message fetcher and parser |
| `Graces Holy Bell/Views/PraySlider.swift` | iPhone slide-to-confirm control (custom DragGesture) |
| `Graces Holy Bell Watch App Watch App/Views/WatchPraySlider.swift` | Watch slide-to-confirm control (custom DragGesture) |
| `waitlist/src/index.js` | Cloudflare Worker: waitlist signup, referral redirect, app-config |
| `.maestro/` (5 files) | iPhone Maestro E2E flows (idle, start, log, stop, settings) |

### Architecture diagram (data flow)

```
┌─────────────┐     capture()     ┌────────────────────┐
│ View/VM     │ ────────────────→ │ AnalyticsService    │
│ (record*)   │                   │ (high-level rec.)   │
└─────────────┘                   └──────┬─────────────┘
                                         │ capture()
                                   ┌─────▼──────────────┐
                                   │ ConsentGatingAnalytics │
                                   │ (drops if !granted)│
                                   └─────┬──────────────┘
                                         │ capture()
                                   ┌─────▼──────────────┐
                                   │ SwappableAnalytics   │
                                   │ (NoOp → PostHog)     │  ← NEW
                                   └─────┬──────────────┘
                                         │ capture()
                              ┌──────────▼──────────────┐
                              │ PostHogTransport OR NoOp │
                              │ (PostHogSDK.setup() here)│
                              └─────────────────────────┘
```

### External services

```
┌─ App ───────────────────────────┐
│                                 │
│  PostHogTransport ─── HTTPS ──→ PostHog (eu.i.posthog.com)
│  RemoteConfig ────── HTTPS ──→ Cloudflare Worker / app-config
│  WaitlistLink ────── HTTPS ──→ Cloudflare Worker / waitlist
│  QR/Referral ─────── HTTPS ──→ boginfactory.com/r/<code>
│                                 │
│  All customer data is LOCAL:    │
│  • SwiftData (prayer logs)      │
│  • UserDefaults (settings)      │
│  • WCSession (Watch sync)       │
│  • UNNotification (Amen alarms) │
└─────────────────────────────────┘
```