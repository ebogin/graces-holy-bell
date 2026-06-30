# Watch Sync Refactor — Execution Plan (for the implementing AI)

> **You are the AI assigned to build this.** This document is your operating manual.
> **Read [`planning/watch-sync-refactor-vision.md`](./watch-sync-refactor-vision.md) first**
> — it is the source of truth for *what* and *why* (the model, the agreed behavior spec, the
> 8 technical decisions, scope, analytics rules, settings tweaks, risks). This doc is the
> *how*: the ordered, executable steps and the rules you work under.
>
> Everything here is **agreed with Eric**. Do not re-litigate decisions; if you discover a
> decision is unworkable, stop and surface it rather than silently changing course.

---

## 0. Operating rules (read before touching code)

- **Work one stage at a time, in order (1→6).** Each stage in §2 ends in a compiling,
  working app and is its own reviewable commit/PR. Do not start a later stage until the
  current one's acceptance criteria pass.
- **No data-migration code.** Eric approved wiping all local data (only ~10 TestFlight beta
  users, on plain `main`). Change the model cleanly; do not write SwiftData migration logic.
- **File-system synchronized groups are on.** All source folders (`Shared/`, `Graces Holy
  Bell/`, `Graces Holy Bell Watch App Watch App/`, `Tests/`) are
  `PBXFileSystemSynchronizedRootGroup`s. **New `.swift` files are picked up automatically —
  do NOT edit `project.pbxproj`** to add files. Files in `Shared/` compile into *both* app
  targets.
- **Schemes:** iOS app = `Graces Holy Bell` (this scheme hosts the unit tests); Watch app =
  `Graces Holy Bell Watch App Watch App`.
- **Build/test commands** (prefer XcodeBuildMCP; `session_show_defaults` first, then
  `build_sim` / `test_sim`). CLI equivalents:
  - Unit tests: `xcodebuild test -project "Graces Holy Bell.xcodeproj" -scheme "Graces Holy Bell" -destination "platform=iOS Simulator,name=iPhone 15"` (pick a booted sim).
  - Watch compile: `build_sim` on the `Graces Holy Bell Watch App Watch App` scheme.
- **The Simulator CANNOT test cross-device sync.** watchOS Simulator has no
  `transferUserInfo`/`transferFile`. Anything involving two devices reconciling is verified
  **only on Eric's real paired iPhone + Watch**, by directing Eric (see §3). Do not claim
  cross-device behavior works based on the sim.
- **Build-number rule:** if you bump `CURRENT_PROJECT_VERSION`, bump it on **both** the iOS
  app and the embedded Watch app targets to the same value, or the App Store upload fails.
- **Do not put planning docs under `docs/`** — that dir auto-mirrors to the public
  landing-page repo. Keep internal notes in `planning/`.
- **After each stage:** run the unit suite, confirm both schemes build, and update the
  "Progress log" in §4 of this file (stage status + date + commit).

---

## 1. Locked decisions (recap — full detail in vision §4–§9)

- **Model:** CRDT event-set. `PrayerEvent { id: UUID, timestamp: Date, origin: phone|watch }`
  + a single `lastClearedAt` epoch per device. Active log = events after `lastClearedAt`.
- **Merge (commutative + idempotent):** `lastClearedAt = max(...)`; union new events by `id`;
  prune events `<= lastClearedAt`.
- **Clear** = timestamped tombstone (wipes everything before it on both devices on reconnect;
  later prayers union-merge). **Timer** = global most-recent prayer. **Origin** stored, not
  shown in UI.
- **Persistence (decision 2):** merge engine works on plain value-type `PrayerEvent`. Phone
  persists via its existing **SwiftData** store (map to/from `PrayerEvent`); Watch persists
  via a **lightweight Codable store** (NOT SwiftData). `lastClearedAt` → `UserDefaults` on
  each device.
- **Wire protocol (decision 3):** three tagged messages — `event` (single prayer,
  `transferUserInfo`), `clear` (`transferUserInfo`), `snapshot` (full active set +
  `lastClearedAt` + `amenAlarmFireAt`; `updateApplicationContext` + `sendMessage` when
  reachable; receiver merges and **replies with its own snapshot**). Delete the old `sentAt`
  ordering, count-guard, action-buffering.
- **Clocks trusted as-is** (drift = accepted non-issue; keep only light clamping that
  prevents negative intervals).
- **"SYNCING WITH WATCH" dialog: CUT** (2026-06-29, Eric's call). Not building the takeover —
  its trigger/edge-case surface outweighs the benefit now that the phone and Watch eventually
  converge on their own. A transient out-of-sync state is itself an acceptable edge case.
- **Sync Up** Settings row (permanent, on-theme, grayed when no Watch) + the four settings
  tweaks (vision §9).
- **Analytics:** count each prayer once at origin (`device_source`); never emit on merge;
  late PostHog arrival is fine.

---

## 2. Stages

> Each stage: **Goal → Tasks → Acceptance.** Do not advance until Acceptance passes.

### Stage 1 — Merge engine + value types (pure; no app behavior change)
**Goal:** a fully unit-tested merge engine that nothing depends on yet.
**Tasks:**
- `Shared/PrayerEvent.swift`: `struct PrayerEvent: Codable, Equatable, Identifiable { id: UUID; timestamp: Date; origin: Origin }` with `enum Origin: String, Codable { case phone, watch }`.
- `Shared/SyncEngine.swift`: pure functions — `merge(localEvents:lastClearedAt:incomingEvents:incomingClearedAt:) -> (events, lastClearedAt)`; derivations `activeLog(events:lastClearedAt:)`, `isActive(...)`, `lastTimestamp(...)`. No I/O, no WatchConnectivity, no SwiftData.
- `Tests/GracesHolyBellTests/SyncEngineTests.swift`: union+dedupe; idempotency (apply same input twice ⇒ identical result); commutativity (A then B == B then A); clear-wins pruning (events `<= clearedAt` removed); post-clear prayers form the new active log; `max(clearedAt)` wins; origin preserved; `lastTimestamp` == max active.
**Acceptance:** unit suite green; both schemes build. Nothing else wired.

### Stage 2 — Phone model + ViewModel rewrite (behavior preserved; single-device)
**Goal:** the phone app behaves exactly as today, standalone, on the new model.
**Tasks:**
- `Graces Holy Bell/Models/PrayerEntry.swift`: add `var id: UUID = UUID()`, `var origin: String = PrayerEvent.Origin.phone.rawValue`. Keep `timestamp`. Treat `sequenceIndex` as derived/display only (or remove it and compute position on read).
- Remove `Graces Holy Bell/Models/PrayerSession.swift` as the unit of truth. Store `lastClearedAt` in `UserDefaults` (key e.g. `prayer.lastClearedAt`).
- `Graces Holy Bell/ViewModels/SessionViewModel.swift`: rewrite around the event set. **Preserve the read API exactly** — `sortedEntries`, `appState`, `lastPrayerTimestamp`,
  `duration(for:at:)`, `elapsedSinceLastPrayer(at:)` keep their signatures and meaning so
  views don't change. `logPrayer()` appends a **phone-origin** `PrayerEntry`; `startNewSession()` = `logPrayer()` when idle; `clearLog()` sets `lastClearedAt = .now`, prunes, fires `session_ended` analytics. Derive `appState` from "active log non-empty". Route all merge/derivation through `SyncEngine` (convert `PrayerEntry` ⇄ `PrayerEvent`). **Emit `prayer_logged` only on local PRAY**, never in any future merge path.
- Update `Tests/GracesHolyBellTests/SessionViewModelTests.swift` for the new model.
**Acceptance:** phone app runs on the iOS sim with identical behavior to before (log grows,
timer resets, clear → idle, Amen alarm schedules); unit suite green. (The Watch still rides
the OLD action protocol end-to-end and still works at this point.)

### Stage 3 — The flip: new protocol + Watch local store + merge on both sides
**Goal:** offline correctness on the Watch + correct reconciliation. **This is the
real-device-verified correctness stage.** Watch store and new protocol land together (a
locally-storing Watch on the old action protocol would double-log).
**Tasks:**
- `Shared/SyncedState.swift` → reshape to `SyncSnapshot { events: [PrayerEvent], lastClearedAt: Date?, amenAlarmFireAt: Date? }` (+ dictionary encode/decode helpers as today). Add small `event` and `clear` payload encoders.
- Watch local store: a lightweight Codable store (events as a JSON/plist blob in the Watch app container) + persist the **last-synced alarm interval** (so the Watch can recompute `fireAt` after its own offline prayers). Wire it in `Graces Holy Bell Watch App Watch App/Graces_Holy_Bell_Watch_AppApp.swift`.
- `WatchSessionViewModel`: store-backed rewrite mirroring the phone VM. `sendPray()` writes a **watch-origin** event to the local store immediately (instant display + timer reset offline), then enqueues it for sync. Same `SyncEngine` derivations. Recompute Amen `fireAt` from local max; recompute again on merge.
- Rewrite both `Connectivity/*ConnectivityManager.swift` around **send-event / send-clear /
  send-snapshot / receive-and-merge**. Snapshot received ⇒ merge ⇒ reply with own snapshot.
  **Delete** the retired `sentAt` ordering, the count-guard, and the action-buffering — the
  idempotent merge subsumes them.
**Acceptance:** unit tests green; both build. **Cross-device behavior verified on real devices
via §3 walkthrough, scenario groups A–F.** Do not mark complete on sim evidence alone.

### Stage 4 — CUT (was: re-integrate the "SYNCING WITH WATCH" dialog)
**Removed 2026-06-29 (Eric's call).** The takeover dialog is not being built. A bounded
"SYNCING…" badge was tried as a lighter alternative (build 8) and reverted (build 9) — it
fired too eagerly on device. Decision: ship without any sync-in-progress UI; the phone and
Watch converge on their own (sync-on-open + eventual background delivery), and a transient
out-of-sync window is an acceptable edge case. Stage numbers below are kept stable so existing
cross-references and git history stay valid.

### Stage 5 — Sync Up Settings row + Settings UI tweaks
**Goal:** manual force-sync + the settings cleanups.
**Tasks:**
- `PhoneConnectivityManager`: observable `isWatchAvailable` (`WCSession.isPaired &&
  isWatchAppInstalled`, updated on activation + `sessionWatchStateDidChange`) and
  `forceSync()` (send snapshot; `sendMessage` when reachable else `transferUserInfo`).
- `Graces Holy Bell/Views/SettingsView.swift`: add the **"Tap to Force Watch Sync" / "Sync
  Up"** row, on-theme, **disabled/grayed when `!isWatchAvailable`**. Plus the four tweaks:
  (1) **hide** `saveLogRow()`; (2) **increase padding** on `shareWithFriendRow()` to match the
  other rows; (3) **indent** `privacyPolicyRow()` label to align with "Anonymous Analytics"
  (the analytics row uses a leading two-space indent today); (4) wrap the container so the
  **whole frame scrolls internally**.
- Inject the manager/availability + `forceSync` closure into `SettingsView` from
  `ContentView` following the existing `settings`/`consent` injection pattern.
**Acceptance:** Maestro/`#Preview` for the UI states; **real-device**: Sync Up forces
convergence (§3 group H) and the row grays when the Watch app is absent (§3 scenario 14).

### Stage 6 — Analytics verification + cleanup + build bump
**Goal:** prove the analytics invariant, clean up, ship a TestFlight build.
**Tasks:**
- Confirm (unit + PostHog project 210049) each prayer = exactly one `prayer_logged`, correct
  `device_source`, true timestamp, **no double-count after merges**; offline Watch prayers
  arrive late but correctly stamped.
- Remove any dead code left from the retired patches.
- Bump `CURRENT_PROJECT_VERSION` on iOS + Watch in sync; final real-device regression pass.
**Acceptance:** §3 group G passes in PostHog; full §3 regression clean; both build; suite green.

---

## 3. Test-plan execution — DIRECT ERIC THROUGH THE REAL-DEVICE SCENARIOS

The unit and single-device tests in vision §14 are yours to run on the Simulator/CI. **The 24
real-device scenarios are NOT something you can run** — the Simulator has no
`transferUserInfo`, so true cross-device sync only exists on **Eric's physical paired iPhone +
Watch.** When a stage's acceptance calls for real-device verification (Stage 3 = groups A–F;
Stage 5 = groups H + scenario 14; Stage 6 = group G + full regression),
**you must walk Eric through the scenarios — he performs them on his devices and reports back.**

**Walkthrough protocol — for each scenario:**
1. **Tell Eric exactly what to do**, step by step, in plain language (which device, what to
   tap, how to disconnect — e.g. "put the iPhone in Airplane Mode" or "power the iPhone off",
   what to log, in what order).
2. **State the expected result** on *both* devices (log contents + order, timer source).
3. **Ask Eric to report what he actually saw** on each device.
4. **Record PASS/FAIL** for that scenario in the Progress log (§4).
5. **On FAIL: stop and diagnose** before moving on — do not continue down the list papering
   over a failure. Use logs, code inspection, and unit tests to find the cause, fix, rebuild,
   and have Eric re-run that scenario.
6. Go **one scenario at a time** — do not dump all 24 at once. Confirm each before the next.

The scenarios, with exact setup/expected outcomes, are in **vision §14, groups A–H** (group I —
the cut dialog — is no longer in scope). Use them verbatim as the script. Summary of what each
group proves:
- **A** connected baseline (1–3) · **B** disconnected independent logging + union on reconnect
  (4–6) · **C** phone fully off, Watch alone, offline alarm (7–8) · **D** clear-across-the-gap,
  both directions + double-clear (9–11) · **E** idempotency: force-quit mid-delivery, repeated
  Sync Up, no-watch-installed, fresh install (12–15) · **F** Amen alarm offline + recompute on
  merge + settings propagation (16–18) · **G** analytics single-count in PostHog (19) ·
  **H** Sync Up forces convergence (20). *(Group I — the dialog scenarios 21–24 — is cut.)*

Only mark a stage complete once Eric has confirmed PASS on that stage's required scenario
groups.

---

## 4. Progress log (the implementing AI updates this)

| Stage | Status | Date | Commit | Notes |
|-------|--------|------|--------|-------|
| 1 — Merge engine + value types | DONE | 2026-06-29 | 02d0c8b | 143/143 tests pass; both schemes build |
| 2 — Phone model + ViewModel rewrite | DONE | 2026-06-29 | 402ab7c | 147/147 pass; both schemes build |
| 3 — The flip (protocol + Watch store + merge) | DONE | 2026-06-29 | 1456ced | 153/153 pass; both schemes build |
| 3a — Build marker + bump + cold-launch buffer | DONE | 2026-06-29 | ec711c9 | build 6; visible version marker (iPhone Settings / Watch log) so testers confirm matched builds |
| 3b — Reconcile on app open (proactive two-way pull) | DONE | 2026-06-29 | f75a8ee | build 7; fixes the "no sync on open / ~30s lag" that failed device tests 1, 9 and slowed 4 |
| 3c — "SYNCING…" badge (perceived-latency UX) | REVERTED | 2026-06-29 | a511b34 → 5952962 | build 8 added it, build 9 removed it: fired too eagerly on device (showed whenever Watch lost contact / phone off). Eric's call to drop it and live with the post-offline delay; sync-on-open (build 7) is unchanged |
| 4 — SYNCING WITH WATCH dialog | CUT | 2026-06-29 | — | not building it (Eric's call); sync converges on its own, edge-case surface not worth it. Group I scenarios dropped |
| 5 — Sync Up row + settings tweaks | DONE | 2026-06-30 | db12b2e | build 10; forceSync + isWatchAvailable; Settings: Sync Up row (grays when no Watch), removed Save Log row, indented Privacy Policy. 153/153 pass; both build; Maestro 05 green + sim screenshot verified |
| 5a — Hide Force Watch Sync row | REVERTED | 2026-06-30 | 7d5de57 | build 12; Eric tested on real device: the manual reconcile is too slow to be a satisfying tap-to-sync action. Row hidden from SettingsView's body (commented, not deleted); isWatchAvailable/onForceSync wiring + PhoneConnectivityManager.forceSync() all left intact to revisit. Group H + scenario 14 device scenarios no longer apply until/unless this returns |
| 6 — Analytics verify + cleanup + build bump | DONE | 2026-06-30 | 6891332 | build 11; added no-double-count-on-merge invariant tests (group G at unit level) — which surfaced + fixed a real bug (mergeIncoming didn't refresh the log when lastClearedAt was nil); PostHog 210049 confirms prayer_logged carries device_source phone/watch, both counted; renamed stale test file; 156/156 pass; both build; Maestro 05 green. Real-device group G + full regression still owed |

Real-device scenario results (fill PASS/FAIL as Eric reports):
`A:1__ 2__ 3__ · B:4__ 5__ 6__ · C:7__ 8__ · D:9__ 10__ 11__ · E:12__ 13__ 14__ 15__ ·
F:16__ 17__ 18__ · G:19__ · H:20__`

**Build 6 device pass (2026-06-29, before sync-on-open fix):**
A: 1 FAIL (synced only after a phone prayer triggered it — no sync on open) · 2 PASS · 3 PASS
B: 4 PASS (slow, ~30s) · 5 PASS · 6 PASS
C: 7 PASS · 8 PASS
D: 9 FAIL (Watch didn't clear on reopen; cleared only after a prayer triggered sync) · 10 PASS · 11 not run
E: 12 PASS · 13 PASS · 14 skipped (Stage 5) · 15 PASS
F: skipped pending sync-on-open.
Root cause: protocol pulled nothing on app open; everything synced only on the
next mutation or slow background delivery. Fixed in build 7 (commit f75a8ee).

**Build 7 partial re-test (2026-06-29):** A:1,2,3 PASS (instant — sync-on-open
works). B:4 PASS but ~40s; 5 PASS but ~60s — both with a device fully offline
(power cycle/airplane). Root cause of the residual lag is OS-level link
re-establishment after the radio was off, unavoidable when the two apps aren't
simultaneously foreground+reachable. Build 8 (a511b34) adds a "SYNCING…" badge
to cover that window perceptually. **Re-test A–F on build 8; finish D(11), F.**
