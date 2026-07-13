# Grace's Holy Bell Release Acceptance Testing Plan

> **For Hermes:** This is a human acceptance and release-gate plan. Do not modify production code while executing it. Test one frozen release candidate, record evidence, file defects, fix on a new build, and restart affected tests.

**Goal:** Decide, with recorded evidence, whether one exact Grace's Holy Bell build is safe and fit for TestFlight and App Store release.

**Scope:** iPhone app, paired Apple Watch app, Live Activity/widget extension, local notifications, local persistence and migration, WatchConnectivity synchronization, PostHog consent/privacy, remote welcome configuration, sharing/referral/waitlist links, accessibility, and App Store submission assets.

**Acceptance-testing definition:** Acceptance testing asks “Can a real customer successfully use this exact release under realistic conditions?” Unit tests prove pieces of code; acceptance tests prove the finished product and release packaging.

---

## 1. Rules for a trustworthy acceptance test

1. **Freeze one candidate.** Record the Git commit, marketing version, build number, and TestFlight build. Do not test a moving branch.
2. **Test the distributed build.** Do final acceptance from TestFlight, not an Xcode Debug install. Debug builds differ in signing, optimization, resources, analytics environment, and lifecycle behavior.
3. **Use production-like configuration.** The candidate must contain the intended PostHog project token, production URLs, privacy manifests, icon, Watch app, and extension.
4. **Write Pass or Fail, never “looks okay.”** Each test below has an observable expected result.
5. **Capture evidence.** For every failure, save device model, OS, app version/build, exact steps, expected result, actual result, and screenshot/screen recording/log when useful.
6. **Retest fixes.** A fix requires a new build. Retest the failed case and a small regression set around it.
7. **Stop on severe failures.** A crash, data loss, privacy/consent violation, wrong production backend, or broken core prayer workflow stops the release.

---

## 2. Release record

Complete this before testing:

| Field | Value |
|---|---|
| Git commit | |
| Branch/tag | |
| Marketing version | |
| Build number | |
| TestFlight build | |
| Xcode version | |
| PostHog project/environment | |
| Remote config version/message ID | |
| Tester | |
| Test start/end | |

**Gate R0 — candidate integrity (mandatory)**

- [ ] Candidate commit equals the intended `main` release commit.
- [ ] iPhone, Watch, and widget report the same intended version/build.
- [ ] Release branch contains every intended `main` change; it is not the stale divergent `release/1.51` branch.
- [ ] Signed archive includes `Secrets.plist`, `silence.caf`, custom font, iPhone app, Watch app, widget extension, and all privacy manifests.
- [ ] Archive validates/exports/uploads without signing or App Store validation errors.
- [ ] Automated gates pass on this commit: iOS tests, Worker tests, Release build/archive.
- [ ] App Store metadata and screenshots name the same version and describe only enabled features.

**Pass:** every item is checked. **Fail:** any mismatch or missing production resource.

---

## 3. Minimum test equipment and matrix

Do not test every possible combination. Use this risk-based minimum:

| Configuration | Purpose | Mandatory? |
|---|---|---|
| Primary physical iPhone on minimum supported iOS, paired with a physical Watch | Real notifications, WatchConnectivity, Live Activity, migration | Yes |
| Same pair upgraded from the latest public/TestFlight build | Persistence and migration | Yes |
| Clean TestFlight install on iPhone + Watch | First-run, consent, defaults | Yes |
| iPhone without an available Watch app | Phone-only behavior | Yes |
| Small-screen iPhone and 40/41/42 mm Watch simulator, visually checked by a human | Clipping/tap targets | Yes if physical small devices unavailable |
| VoiceOver on primary iPhone and Watch | Core accessibility | Yes |
| Largest Accessibility Text Size on iPhone; large text on Watch | Layout/accessibility | Yes |
| US/non-EU region and one EU/EEA/UK region on clean state | Consent policy | Yes |

If the deployment target remains iOS/watchOS **26.2**, explicitly approve that customer-compatibility decision. Otherwise lower it before acceptance and add one device on the true minimum OS.

---

## 4. Defect severity and release policy

| Severity | Meaning | Examples | Release rule |
|---|---|---|---|
| **S0 Blocker** | Unsafe, unlawful, or unusable release | crash on launch; data loss; prayer content transmitted; analytics before required consent; wrong backend; archive rejected | Must fix |
| **S1 Critical** | Core promise fails for a normal user | cannot start/log/stop; duplicate/lost prayers; Watch sync corrupts state; alarm does not fire | Must fix |
| **S2 Major** | Important feature fails but workaround exists | sharing fails; remote welcome broken; Live Activity stale; major accessibility barrier | Fix or explicitly defer with rationale; accessibility of the core slider should be treated as S1 |
| **S3 Minor** | Cosmetic or low-impact | small spacing issue, harmless wording defect | May ship if documented |

**Final exit criteria:**

- Zero open S0 or S1 defects.
- Every mandatory test passes on the final TestFlight build.
- Every S2 is fixed or explicitly accepted in writing with impact/workaround.
- No code/config changes after the final acceptance run.
- App Store Connect privacy answers, policy, screenshots, version/build, URLs, and archive all describe the same product.

---

## 5. Fast smoke test — run on every candidate (10–15 minutes)

### A01 — Clean launch
**Setup:** Delete iPhone and Watch apps, reinstall the candidate from TestFlight, launch iPhone.

1. App opens without crash or prolonged blank screen.
2. Correct icon, title, pixel font, welcome content, slider, share, and settings appear.
3. No debug seed data or debug-only controls appear.

**Pass:** usable idle screen appears in under 5 seconds on a normal connection; bundled fallback appears if offline.

### A02 — Start, log, and stop
1. Partially drag the prayer slider and release.
2. Fully slide it to start.
3. Wait at least 10 seconds; background and foreground once.
4. Fully slide again to log another prayer.
5. Tap Stop, first cancel, then open again and confirm.

**Pass:** partial drag does nothing; full slide creates exactly one entry; timers advance correctly across backgrounding; second slide creates exactly one additional entry; Cancel preserves the session; confirmation ends it and returns to idle.

### A03 — Settings persistence
1. Open Settings.
2. Change one alarm duration, Live Activity toggle, analytics toggle, and Prayer Log Editing toggle.
3. Force-quit and relaunch.

**Pass:** intended settings persist; hidden Prayer History remains absent while its compile-time flag is off; build/version row is correct.

### A04 — Paired Watch smoke
1. Open Watch app.
2. Start or log a prayer on Watch.
3. Confirm it appears on iPhone.
4. Log one on iPhone and confirm it appears on Watch.

**Pass:** both devices converge to the same ordered, duplicate-free log within 10 seconds while reachable.

### A05 — Public links
Open Privacy Policy, Share with a Friend, QR/referral link, waitlist, contact, and share sheet.

**Pass:** every page is HTTPS, loads successfully, has correct branding/content, and no placeholder URL or stale launch copy appears.

---

## 6. Core functional acceptance

### A06 — Accidental-action protection
- Tap the slider without dragging.
- Drag to roughly 50% and release.
- Drag backward/interrupt a drag.
- Complete one full drag.

**Pass:** only the completed full drag logs exactly one prayer. No duplicate from one gesture.

### A07 — Long-running timer/lifecycle
1. Start a session.
2. Lock the phone for 10 minutes.
3. Use another app, return, then restart Grace's Holy Bell.

**Pass:** elapsed time is based on real timestamps, not paused UI ticks; no negative/jumped timer; session and entries remain.

### A08 — Date boundary and clock changes
Run a session across midnight if practical, then separately change time zone while a session exists.

**Pass:** entries remain chronologically coherent; durations are not negative; app does not crash. Record expected product behavior for manual clock rollback/forward.

### A09 — Prayer editing feature
1. Enable Prayer Log Editing.
2. Log at least three prayers.
3. Edit a middle timestamp, add/trim/clear an intention, delete a prayer, and edit the most recent prayer.
4. Sync with Watch after each type of change.

**Pass:** ordering and durations recalculate correctly; notes are correct; deleted prayer does not reappear from a stale Watch; most-recent edit updates timer base; no prayer is duplicated.

### A10 — End-session semantics
Test a one-prayer and multi-prayer session. Cancel once and confirm once.

**Pass:** Cancel causes no mutation. Confirm ends the current session and returns to idle. If history is deliberately hidden, no unfinished history UI leaks into Settings.

---

## 7. Persistence and upgrade acceptance — release blockers

### A11 — Upgrade from authentic earlier data stores
Run two in-place upgrades when the old builds are available. Do not delete the app between old-build setup and candidate installation.

**A11a — 1.41/V1 store (highest risk):** Install the genuine 1.41-era build, create at least three recognizable prayers plus non-default settings, then upgrade to the candidate.

**Pass:** every old prayer survives in order; the app does not resemble a fresh install; new writes persist after two relaunches; Watch sync does not duplicate migrated rows.

**A11b — 1.42/1.43/V2 store:** Create both phone- and Watch-origin prayers on an authentic 1.42/1.43-era build, then upgrade in place.

**Pass:** counts and origins remain stable across repeated sync; no phantom notes/deletions appear; new edit/delete operations persist and sync; consent and all UserDefaults-backed settings remain unchanged.

If either authentic starting build is genuinely unavailable, record the case as **Blocked** and explicitly accept that migration risk before release; automated migration tests alone are not equivalent to an installed-store upgrade.

### A12 — Relaunch durability
Create/edit/delete data, force-quit, reboot iPhone, and reopen.

**Pass:** final state survives exactly; deleted data stays deleted; no duplicate entries.

### A13 — Low-storage/recovery awareness
You do not need to fill the device dangerously. Confirm normal operation with limited free space and inspect telemetry/logs for persistence recovery.

**Pass:** no silent data loss. If the app ever recreates its store, treat it as S0 until the cause and user impact are understood.

---

## 8. iPhone–Watch synchronization matrix — release blockers

For each test, write the expected prayer count/timestamps before reconnecting and compare both devices afterward.

### A14 — Reachable, alternating origin
Log P1 phone, P2 Watch, P3 phone, P4 Watch.

**Pass:** both show exactly P1–P4 in chronological order; no duplicates.

### A15 — Watch offline, then reconnect
1. Disconnect Watch from phone/network.
2. Log two prayers on Watch.
3. Reconnect and open both apps.

**Pass:** phone receives both exactly once; both converge within 30 seconds.

### A16 — Phone unavailable/cold launch
1. Force-quit or power off phone.
2. Log prayers on Watch.
3. Start phone and launch app.

**Pass:** queued Watch prayers are not lost and appear once after phone configuration completes.

### A17 — Phone offline changes
Disconnect Watch; log/edit/delete on phone; reconnect.

**Pass:** Watch receives final state, including deletion tombstones; deleted entries do not resurrect.

### A18 — Concurrent conflict
While disconnected, create changes on both devices, including a phone edit/delete and a Watch prayer, then reconnect.

**Pass:** deterministic merge; no crash, duplicates, lost unrelated prayer, or resurrection. Record exact expected winner for same-record conflicts.

### A19 — Clear/stop propagation
Stop/clear on one device while the other is disconnected, then reconnect.

**Pass:** stale device does not restore the cleared session.

### A20 — Watch install states
Test phone with no paired Watch, paired Watch without app, newly installed Watch app, and Watch app upgrade.

**Pass:** phone remains usable; availability UI is truthful; first sync after install/upgrade converges without duplicates.

---

## 9. Amen Alarm and notifications — physical devices required

Use the shortest available interval where possible. Record whether the app is foregrounded, backgrounded, or device locked.

### A21 — Permission allowed
Enable phone alarm and grant notifications. Use the built-in 30-second test interval if it is intentionally present in the candidate; otherwise use the shortest supported interval. Log a prayer and wait for the fire time.

**Pass:** one local notification/haptic occurs at the expected time; bundled silent sound does not produce an audible alert; opening/tapping leaves app stable.

### A22 — Permission denied
On a clean install, deny notification permission, enable alarm, and continue using the app.

**Pass:** no crash or repeated permission harassment; UI does not falsely promise delivery; user has a sensible path to Settings if one is offered.

### A23 — Phone-only, Watch-only, both
Test each toggle combination.

**Pass:** only selected devices alert; disabling cancels pending alarms; changing duration reschedules; logging another prayer moves the fire time; stopping clears pending alarm.

### A24 — Offline/background alarm
Schedule, disconnect devices/lock screens, and wait.

**Pass:** local notification does not depend on internet or the counterpart device being reachable.

### A25 — AMEN in-app state
Remain in app until interval elapses, then background/foreground around the boundary.

**Pass:** progress and AMEN state are correct; haptics do not run indefinitely after reset/stop; no runaway timer/battery behavior.

---

## 10. Live Activity and extension acceptance

### A26 — Lifecycle
Enable Live Activity, start session, log another prayer, lock phone, inspect Lock Screen and Dynamic Island where supported, then stop.

**Pass:** timer/state update, survive lock/background, and disappear promptly after stop. No orphaned activity remains after relaunch.

### A27 — Toggle behavior
Turn Live Activity off during an active session and back on.

**Pass:** off ends existing activity; on creates/reconciles the intended current activity without duplicates.

### A28 — Reboot/relaunch
Start an activity, force-quit/relaunch; optionally reboot.

**Pass:** app reconciles stale activity to persisted session state.

### A29 — Watch Smart Stack/widget appearance
Inspect all supported presentations on a real Watch if available.

**Pass:** text is legible, timer fits, no placeholder/debug state, and tapping opens the intended app context.

---

## 11. Privacy, consent, and analytics — release blockers

### A30 — EU/EEA/UK clean install
Set device Region to an EU/EEA/UK country before a clean install.

1. Launch while observing network traffic if possible.
2. Do not choose Allow or Deny immediately.
3. Exercise the privacy-policy link, then Deny.
4. Use the app and verify PostHog events do not arrive.
5. Change to Allow and generate one known event.

**Pass:** consent screen cannot be bypassed; choices have equal prominence; no analytics/event transmission before Allow; denied use emits no events; after Allow, exactly the expected anonymous event reaches the production project.

**Current implementation risk to resolve before relying on this test:** PostHog SDK 3.62 loads project remote config during `setup` even with `preloadFeatureFlags = false`. Initialize PostHog only after consent, or prove/accept the pre-consent request with policy/legal review.

### A31 — Non-EU clean install
Set Region to United States, clean install, inspect default Analytics setting, opt out, relaunch, and opt back in.

**Pass:** default matches policy; opt-out persists and stops new events; opt-in resumes; no duplicate launch/session events.

### A32 — Data minimization
Inspect several production PostHog events.

**Pass:** no prayer/intention text, name, email, phone, precise location, Apple ID, or cross-app tracking identifier; only documented anonymous ID, coarse geo, app/device context, and documented usage taxonomy.

### A33 — SDK feature controls
Verify live PostHog project config and app config before submission.

**Pass:** exception autocapture is off unless disclosed; session replay is off; screen/lifecycle autocapture is off; surveys/autocapture are intentionally configured; no unexpected `$exception`, replay, survey, or autocapture traffic.

### A34 — Privacy reconciliation
Compare the final archive’s aggregated privacy report/manifests with App Store Connect answers, in-app policy, and public policy.

**Pass:** actual collection and all four disclosures agree. Resolve the embedded PostHog declarations for **Other Usage Data**, **Crash Data**, and **Other Diagnostic Data**. A bundled SDK capability is not proof those data are actually collected, but it must be reconciled with actual configuration and Apple’s generated report. Current live config reports crash autocapture and session recording off.

---

## 12. Remote welcome configuration and failure handling

### A35 — Normal config
Load the current production welcome message.

**Pass:** intended audience/message appears; no code-like markup or broken layout.

### A36 — Offline and timeout
Launch fresh with airplane mode; then restore network.

**Pass:** bundled/cached fallback appears promptly; app and prayer controls never block on config; later refresh succeeds.

### A37 — Malformed/unknown content
In a staging Worker or controlled test, provide unknown blocks, missing fields, insecure HTTP image/link, overlong text, and unreachable image.

**Pass:** invalid blocks are ignored, HTTPS restrictions hold, text is bounded, and core app remains usable.

### A38 — Rollback drill
Before release, document who controls the admin token and rehearse restoring the known-good welcome payload.

**Pass:** rollback can be completed and verified in under 10 minutes without an app release; token is not committed or exposed.

---

## 13. Sharing, referral, and web/backend acceptance

### A39 — Phone share
Open Share with a Friend, scan QR with another device, and use native ShareLink.

**Pass:** both carry the same intended referral code/source and open the HTTPS waitlist/redirect page.

### A40 — Watch QR
Open Watch share screen and scan QR from multiple distances.

**Pass:** QR renders promptly, scans, and maps to the correct referral source; back navigation works.

### A41 — Signup
Submit valid signup, duplicate email, invalid data, no SMS consent, and SMS consent.

**Pass:** validation is clear; duplicate behavior is expected; confirmation arrives; stored consent matches choice; no CSV formula injection in export.

### A42 — Referral redirect cutover
Before launch, waitlist redirect is intentional. At App Store launch, set and test `REDIRECT_URL`.

**Pass:** `/r/<code>` preserves attribution and reaches the intended waitlist or exact App Store listing; no placeholder app ID; referral analytics failure does not prevent the human redirect.

Also verify that the anonymous referral code remains stable across ordinary relaunches but changes after a true uninstall/reinstall, as intended.

### A43 — Admin protection
Verify export and app-config write endpoints reject missing/wrong tokens.

**Pass:** unauthorized requests receive no private data and cannot change content.

---

## 14. Accessibility and human visual acceptance

### A44 — VoiceOver core journey
With VoiceOver on, attempt: launch, start session, log prayer, hear timer/log state, stop/cancel/confirm, open Settings, change alarm, open Privacy, and share.

**Pass:** every core control has a meaningful label/state/hint and can be activated without a sighted drag gesture; focus order is logical; changes are announced.

**Known source-level concern:** the iPhone and Watch prayer sliders expose only an accessibility identifier and a `DragGesture`; they have no accessibility action or adjustable action. Treat inability to start/log with VoiceOver as an S1 release defect.

### A45 — Dynamic Type
Use the largest Accessibility Text Size.

**Pass:** essential labels and controls remain visible/operable; scrolling is available; no overlap or clipped meaning. Pixel font may scale, but test the result rather than assuming `relativeTo` is sufficient.

### A46 — Reduce Motion / flashing
Enable Reduce Motion and test the AMEN blinking state.

**Pass:** no harmful or unusable animation; controls remain understandable. Consider a non-flashing alternative if the repeated 0.5-second inversion is uncomfortable.

### A47 — Contrast and color independence
Check idle, active, settings, consent, alarm-progress, and disabled states in light/dark device appearances.

**Pass:** text and control states are legible and not conveyed by color alone.

### A48 — Small screens
Human-check iPhone SE/smallest supported phone and smallest supported Watch.

**Pass:** no clipped buttons, unreadable timer, inaccessible bottom controls, or overlap with rounded Watch corners.

### A49 — Orientation and interruptions
Confirm iPhone portrait restriction is intentional. Test incoming call/notification, Control Center, and app backgrounding during a drag/session.

**Pass:** no accidental prayer, stuck gesture, lost state, or layout rotation defect.

---

## 15. Exploratory and stability testing

### A50 — 30-minute exploratory session
Without following a script, use the app as a customer: rapidly open/close settings, repeat slides, background frequently, switch phone/Watch origin, toggle connectivity, edit data, and share.

**Pass:** no crash, hang, duplicate, stale state, surprising data loss, runaway haptics, or obvious battery/heat issue.

### A51 — Overnight/soak
Leave one active session overnight with alarm/Live Activity in the intended state.

**Pass:** timers remain correct, no notification storm, no orphaned Live Activity, no significant unexplained battery drain, and both devices reconcile next morning.

---

## 16. App Store submission acceptance

### A52 — Metadata
- [ ] App name/subtitle/description/keywords are current.
- [ ] “What’s New” matches the candidate.
- [ ] Support, marketing, privacy, and contact URLs return 200 without authentication.
- [ ] No mention of disabled Prayer History or other unavailable functionality.
- [ ] Reviewer notes explain the slider, notification behavior, Watch companion, and any non-obvious feature.

### A53 — Screenshots
- [ ] Screenshots are from the final candidate or faithfully represent it.
- [ ] Correct device-family dimensions are accepted by App Store Connect.
- [ ] At least one iPhone set is complete; Watch screenshots are assigned correctly.
- [ ] No debug data, simulator artifacts, stale version copy, or misleading feature appears.

Current source assets observed: iPhone `1320×2868`; Watch `422×514`. Final authority is App Store Connect’s upload validation.

### A54 — Privacy/compliance
- [ ] App Privacy answers reflect final actual collection.
- [ ] Privacy policy and in-app copy match.
- [ ] Export compliance answer matches `ITSAppUsesNonExemptEncryption = NO`.
- [ ] Age rating/content-rights answers are complete.
- [ ] PostHog crash/error tracking, session replay, Other Usage Data, coarse location, and device ID decisions are documented.

### A55 — Final distributed-build check
After TestFlight processing, install that exact build on clean and upgrade paths and rerun A01–A05, A11, A14–A16, A21–A23, A26, A30/A31, A39, and A44.

**Pass:** all pass with no new S0/S1. Then—and only then—submit that same build for review.

---

## 17. Test-result template

Copy this row for each case:

| Test ID | Build | Device/OS | Setup | Result | Evidence/notes | Defect |
|---|---|---|---|---|---|---|
| A01 | | | Clean TestFlight install | Pass / Fail / Blocked | | |

Use **Blocked** only when the setup cannot be produced; a blocked mandatory test prevents release unless risk is explicitly accepted.

## 18. Defect template

```markdown
# [S0/S1/S2/S3] Short title

- Build/commit:
- Device and OS:
- iPhone/Watch connectivity state:
- Install state: clean / upgrade
- Region, notification permission, analytics consent:
- Preconditions:
- Steps:
  1.
  2.
  3.
- Expected:
- Actual:
- Reproduction rate: e.g. 3/3
- Screenshot/video/log:
- Workaround:
```

## 19. Recommended execution order for a solo beginner

**Pass 1 — 30 minutes:** R0 + A01–A05. Stop if any fail.

**Pass 2 — 60–90 minutes:** A06–A13 (core + persistence/upgrade).

**Pass 3 — 60–90 minutes:** A14–A20 (Watch sync matrix).

**Pass 4 — 60 minutes plus alarm waits:** A21–A29 (notifications + Live Activity).

**Pass 5 — 60 minutes:** A30–A43 (privacy, remote config, sharing/backend).

**Pass 6 — 45 minutes:** A44–A49 (accessibility + visual/device checks).

**Pass 7 — 30 minutes plus overnight:** A50–A51.

**Pass 8 — 30 minutes:** A52–A55 and final sign-off.

Ask one person who did not build the feature to perform at least the smoke test, core prayer journey, Watch sync, permission denial, and VoiceOver journey. Fresh eyes catch assumptions the developer no longer notices.

---

## 20. Final sign-off

```markdown
Release candidate:
Decision: SHIP / NO-SHIP
Date:

Mandatory tests passed:
Open S0:
Open S1:
Accepted S2 and rationale:
Known S3:
Privacy reconciliation completed by:
App Store metadata reviewed by:
Physical iPhone/Watch test completed by:
Final TestFlight smoke completed by:

I confirm no code or production-config changes occurred after this test run.
Signed:
```
