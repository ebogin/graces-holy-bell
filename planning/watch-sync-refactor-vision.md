# Watch Sync Refactor — Project Vision

> Status: **VISION + TECHNICAL DECISIONS + BUILD PLAN AGREED** (this document).
> Build plan in §13, test plan in §14. Ready to implement, staged.
> Watch persistence decision: **lightweight Codable store** (not SwiftData) — confirmed.
> This is an internal planning doc — intentionally **NOT** under `docs/` (that dir
> auto-mirrors to the public landing-page repo). Keep it here in `planning/`.
>
> Audience: a fresh AI session or engineer who has never seen this work. Read this
> top-to-bottom and you understand *what* we're building and *why*, without re-asking Eric.

---

## 1. One-sentence goal

Make prayers and prayer-sessions logged on the **Apple Watch while it is away from the
iPhone** (phone dead, out of battery, out of range) fully functional on the Watch — the
log displays correctly and the timer keeps running locally — and make the two devices
**reconcile to a single correct, deduplicated state when they reconnect**, without ever
losing or double-counting a prayer.

The iPhone remains the primary device. This refactor also **lays the foundation** for a
future where the Watch runs fully standalone, but builds **none** of that standalone
feature set now.

---

## 2. What the app is (context)

**Grace's Holy Bell** is a personal prayer-*duration* awareness tool. It helps a user
notice their prayer cadence (interval/duration between prayers), not content or intensity.
The central interaction: the user slides **PRAY** to log a prayer; the app shows a running
timer since the last prayer and a log of prayers in the current session. An optional
**Amen Alarm** haptically reminds the user some configurable duration after their last
prayer. There is an iPhone app and an embedded watchOS companion app.

Current deployment: live to **~10 TestFlight beta users**. The sync-patch work on branches
(`distracted-wilbur`, `admiring-raman`) is **only on Eric's own devices** — beta users are
running plain `main`.

---

## 3. The problem (why this refactor exists)

### Root cause
On `main`, the Watch is a **thin proxy**. It has **no local persistent store** and is not a
source of truth. The iPhone owns the only `SwiftData` store (`PrayerSession` +
`PrayerEntry`). The Watch merely:
- sends actions (`START`, `PRAY`, `CLEAR_LOG`) to the phone, and
- displays a `SyncedSessionState` snapshot the phone pushes back.

So when the two are disconnected, the Watch **structurally cannot** record or correctly
display a prayer — it fires an action into the void and waits for state that isn't coming.

### Identity-by-position
Prayers are identified by **position**: `PrayerEntry.sequenceIndex` (0, 1, 2…). Two devices
logging independently both mint index 0, 1, 2… for *different* prayers, so their logs
**cannot be merged by construction**. Identity must become a stable UUID, not a position.

### Symptoms that were chased with patches (all superseded by this refactor)
- Watch prayers don't display / timer doesn't reset while the phone is off.
- On reconnect, queued actions deliver in a ~5s burst → the phone briefly shows a stale,
  shrinking-looking log ("my prayers were lost!").
- A count-based staleness guard could permanently **wedge** sync.
- Queued Watch actions dropped if delivered before the phone's ViewModel was wired up.

These were addressed with stacked patches (optimistic Watch updates + true timestamps,
`sentAt` ordering, action buffering, dual-channel push, a "SYNCING WITH WATCH" takeover
dialog). They papered over a model that can't express the desired behavior. **This refactor
replaces the model; the patches are retired or re-implemented cleanly on top of it.**

---

## 4. Core model (agreed)

Replace "one mutable session container" with a tiny **CRDT-style event set + clear epoch**.

A prayer is an **immutable event**:
```
PrayerEvent { id: UUID, timestamp: Date, origin: "phone" | "watch" }
```

Each device persists locally:
- the set of all **events it knows about**, and
- a single **`lastClearedAt: Date?`** ("clear epoch").

Everything else is **derived** (never stored as identity):
- **Active log** = events with `timestamp > lastClearedAt`, sorted by `timestamp`.
- **App is ACTIVE** ⟺ the active log is non-empty (replaces "a session exists").
- **"Prayer #N"** = position in the sorted active log (display only, recomputed every time).
- **Timer** = `now − max(active event timestamp)`.

### The merge (identical on both devices; commutative + idempotent)
Given local `(events, lastClearedAt)` and an incoming `(events', lastClearedAt')`:
1. `lastClearedAt = max(lastClearedAt, lastClearedAt')` (nil = distant past).
2. Insert any incoming event whose `id` is not already present.
3. Prune every event with `timestamp <= lastClearedAt`.

Because merge is order-independent and idempotent, **sync can never wedge** regardless of
delivery timing, duplicates, or missed messages — re-delivery and out-of-order delivery
self-heal.

---

## 5. Agreed behavior spec

All confirmed with Eric.

1. **Union + order by time.** When both devices logged independently while disconnected,
   on reconnect both show the union of all prayers, deduplicated, ordered by timestamp.
   No prayer is ever lost.
2. **Origin tag.** Every prayer stores where it was logged (`phone` | `watch`). **Not**
   surfaced in the UI now; the data element only. (Future: a column in the log showing
   watch vs phone.)
3. **Timer from the global most-recent.** After merge, the timer on *both* devices counts
   from the single most-recent prayer across both devices.
4. **Clear semantics:**
   - **Connected:** a Clear affects both devices immediately.
   - **Disconnected then reconnect:** a Clear is a timestamped tombstone. On reconnect,
     **everything before the latest clear timestamp is removed on both devices**, and
     prayers **after** the clear timestamp (from either device) union-merge into the new
     session.
5. **Amen Alarm offline:** while disconnected, the Watch fires its own Amen Alarm based on
   its **local** most-recent prayer (using the **last alarm interval it was synced** — the
   alarm duration/enabled settings stay phone-controlled-and-synced for now).
6. **Amen Alarm on merge:** if the combined most-recent prayer changes at reconnect, the
   alarm is **recomputed from the new max timestamp** on both devices.
7. **"SYNCING WITH WATCH" dialog: KEEP as-is.** Eric wants the full takeover so the merge
   lands behind a curtain rather than animating in front of the user. (See §7.)
8. **Manual force-sync:** a permanent **Settings row** ("Tap to Force Watch Sync" / "Sync
   Up"), on-theme, grayed out when no Watch is installed.
9. **Analytics counted once, at origin:** see §8.

### Clocks
Eric's explicit call: **trust device clocks as-is.** Apple keeps the paired devices NTP-
synced; the rare cross-device drift edge case (e.g. a Watch clock minutes-fast causing a
clear to wipe a prayer logged after it in real time) is accepted as a non-issue. Keep only
light defensive clamping that already prevents *negative* intervals. No logical clocks.

---

## 6. Scope

### In scope (now)
- Stable prayer identity (UUID) + `origin` tag.
- Event-set + clear-epoch model replacing the single-session container.
- A shared, unit-tested merge engine compiled into both targets.
- The Watch gets its **own local persistent store** so it works offline.
- A clean sync protocol (event / clear / snapshot) running the same merge on both sides.
- Re-integrate the "SYNCING WITH WATCH" takeover dialog into `main`, re-wired to the new
  merge (it currently lives only on the `admiring-raman` branch, not `main`).
- Settings: the Sync Up row + the four UI tweaks in §9.
- Analytics single-count guarantee (§8).
- Comprehensive **real-device** test plan (the watchOS Simulator cannot do
  `transferUserInfo`/`transferFile`; final verification must be on a physical iPhone+Watch).

### Out of scope (future "somedays" — Eric confirmed all are YES eventually, NOT now)
- Watch keeping its own full prayer log **indefinitely** with the phone never required.
- Watch sending analytics **directly** to PostHog (over cellular/WiFi, not proxied).
- Watch having its **own referral/QR code**, settings, consent.
- Watch as a **full peer / fully self-sufficient** device.
- **Surfacing** the origin tag (watch/phone) in the log UI.
- Moving **full Amen Alarm storage + control onto the Watch** (needs its own UI).

For now: **phone stays primary.** We only add offline correctness on the Watch + correct
reconciliation, while structuring the data/merge so the somedays are incremental later.

---

## 7. The "SYNCING WITH WATCH" dialog (keep)

Decision: **keep the full-screen takeover as-is.** Rationale (Eric): when the merge happens,
hiding it behind the curtain is less jarring than watching prayers pop in live.

Implementation note for whoever builds this: the dialog currently exists **only on branch
`admiring-raman`** (commits `c3aafce`, `4c7f669`, building on the offline-PRAY commit
`4b69ce8`), with a design doc at repo-root `WatchSyncIndicator_Proposal.md`. It is **not in
`main`.** "Keep as-is" therefore means: bring that UI into this work and **re-wire its
trigger to the new merge** (it was designed to mask the old burst-delivery window). The
detection signal it used — `WCSession.hasContentPending` — still applies: it's the only
"data is queued" signal available before the first queued item lands. Scenario B (phone
idle, a whole session was started on the Watch while the phone was off) still applies and is
the strongest justification for the takeover.

---

## 8. Analytics rules (must not regress)

The product's core invariant: **each prayer is counted exactly once, by the device where it
originated, tagged `device_source = phone | watch`, with the true prayer timestamp.**

- Phone logs a prayer → phone emits `prayer_logged`, `device_source = phone`.
- Watch logs a prayer (even offline) → counted once as `device_source = watch`, stamped with
  the real prayer time. PostHog lives **only on the phone** today (Watch is an analytics
  proxy), so a Watch-originated event is **held and emitted when the devices reconnect**.
- **Merging a prayer received from the other device must NOT emit `prayer_logged`** — it was
  already counted at origin. This is the key regression risk the merge introduces.
- **Late arrival to PostHog is always acceptable.** PostHog is reviewed weekly, never needs
  real-time. As long as events carry the correct true timestamp, duration/interval analytics
  stay accurate even when ingestion is delayed.

---

## 9. Settings UI changes (bundle with the Sync Up row)

The Sync Up row is added in `Graces Holy Bell/Views/SettingsView.swift`. While there, also:
1. **Hide** the "Save Log to Notes" row (`saveLogRow()`) — backlogged, not deleted.
2. **Increase padding** on "Share with a Friend" (`shareWithFriendRow()`) to match the other
   rows' spacing.
3. **Indent "Privacy Policy"** (`privacyPolicyRow()`) so its label lines up with "Anonymous
   Analytics" (which is rendered with a leading `"  "` two-space indent today).
4. **The whole Settings frame scrolls internally** (wrap the container in a scroll view) so
   the growing list (now with the Sync Up row) doesn't overflow.

---

## 10. Constraints & key facts for the builder

- **Data wipe is acceptable.** Eric approved wiping everyone's local data during this
  refactor → **no SwiftData migration code needed**; the model can change cleanly.
- **Real-device verification is mandatory.** watchOS Simulator does **not** support
  `transferUserInfo`/`transferFile`; cross-device sync can only be verified on a physical
  paired iPhone + Watch. The Simulator is still fine for building, unit tests, and
  single-device UI.
- **Build-number rule:** bumping the iOS build number requires bumping the embedded Watch
  app target to match, or the App Store upload fails.
- **Xcode project structure:** `Shared/` is a *synchronized group* on both app targets — new
  files added there compile into both apps with no `.pbxproj` edits. There is one
  iPhone-hosted unit-test target; the Watch is verified compile-only.
- **watchOS has no CoreImage** (relevant only to the QR feature, not this work).

### Current files (on `main`) this refactor touches
- `Graces Holy Bell/Models/PrayerEntry.swift` — add stable `id`, `origin`.
- `Graces Holy Bell/Models/PrayerSession.swift` — removed or reduced (epoch replaces it).
- `Graces Holy Bell/ViewModels/SessionViewModel.swift` — event/epoch rewrite (currently
  session-container based, `sequenceIndex`-ordered).
- `Graces Holy Bell/Connectivity/PhoneConnectivityManager.swift` — new protocol + merge
  (currently a state-push proxy with action de-dupe).
- `Graces Holy Bell Watch App Watch App/ViewModels/WatchSessionViewModel.swift` —
  store-backed rewrite (currently holds plain structs pushed from the phone).
- `Graces Holy Bell Watch App Watch App/Connectivity/WatchConnectivityManager.swift` — new
  protocol + merge (currently action-sender + state-receiver).
- `Graces Holy Bell Watch App Watch App/Graces_Holy_Bell_Watch_AppApp.swift` — add a
  `modelContainer` so the Watch has a local store.
- `Shared/SyncedState.swift` — reshape the wire payload (currently `SyncedSessionState`
  with position-based `SyncedEntry { timestamp, sequenceIndex }` + `amenAlarmFireAt`).
- `Shared/SyncEngine.swift` *(new)* — pure merge + derivations, shared by both targets.
- `Graces Holy Bell/Views/SettingsView.swift` (+ `ContentView.swift`) — Sync Up row +
  the §9 tweaks + manager injection.
- `Tests/` — new `SyncEngineTests`; update `SessionViewModelTests`.

---

## 11. Tooling that helps this project

- **XcodeBuildMCP** — `build_sim` (both schemes), `test_sim` (run the unit suite incl. the
  new `SyncEngineTests`). Already in use. Note: **device** workflows are off by default in
  XcodeBuildMCP; to build/install/run on the physical iPhone+Watch via MCP, device workflows
  must be enabled (else use Xcode directly for the real-device runs).
- **Maestro** (`~/.maestro/bin/maestro`, flows in `.maestro/`) — drives the iOS Simulator for
  single-device E2E (Settings UI, the `#if DEBUG` "TEST SYNC" button). **Cannot** test true
  cross-device sync (sim has no `transferUserInfo`).
- **PostHog MCP** — after real-device runs, query project 210049 to confirm each prayer
  produced exactly one `prayer_logged` with the correct `device_source` and true timestamp
  (validates the §8 single-count guarantee). Late arrival is expected/fine.
- **`verify` / `run` skills** — launch the app to confirm a change works in the real app, not
  just tests.

---

## 12. Open risks (builder should keep in mind)

- **Real-device-only bugs are slow to find.** This is why the build plan should be **staged**
  so a regression can be isolated to a stage (the data-wipe-OK fact makes staging cheap —
  no migration scaffolding per stage).
- **Analytics double-count** on merge is the subtle regression to guard (see §8).
- **Dialog re-wire**: the kept takeover was built against the *old* burst-delivery window;
  its trigger must be re-pointed at the new merge/`hasContentPending` flow.
- **Clock trust** is an accepted non-issue per Eric, but is the one place the data rules can
  theoretically misbehave — documented here so nobody "fixes" it as a surprise bug later.

---

## 13. Build plan (staged)

Staged deliberately: real-device-only verification is slow, and the data-wipe-OK fact means
no stage needs migration scaffolding, so isolating a regression to a stage is cheap. Each
stage compiles both targets and leaves the app in a working state.

### Stage 1 — Merge engine + value types (pure, no app behavior change)
- New `Shared/PrayerEvent.swift`: value type `{ id: UUID, timestamp: Date, origin: Origin }`.
- New `Shared/SyncEngine.swift`: pure `merge(localEvents, lastClearedAt, incoming) ->
  (events, lastClearedAt)` + derivations (`activeLog`, `isActive`, `lastTimestamp`).
- New `Tests/.../SyncEngineTests`: union+dedupe, idempotency, commutativity, clear-wins
  pruning, post-clear new session, origin preserved.
- **Verify:** unit tests green; both targets compile. Fully sim/CI-verifiable. No wiring yet.

### Stage 2 — Phone model + ViewModel rewrite (behavior preserved, single-device)
- `PrayerEntry` gains `id: UUID` + `origin: String` (defaults). `PrayerSession` removed.
  `lastClearedAt` → `UserDefaults`.
- `SessionViewModel` rewritten around the event set, **read API preserved** (`sortedEntries`,
  `appState`, `lastPrayerTimestamp`, `duration(for:)`, `elapsedSinceLastPrayer`). `logPrayer`
  appends a phone-origin event; `clearLog` sets the epoch + prunes; analytics emitted **only**
  on local action.
- Update `SessionViewModelTests`.
- **Verify:** phone app behaves exactly as before, standalone, on the sim; unit tests green.
  (Watch still rides the OLD action protocol end-to-end at this point — still works.)

### Stage 3 — The flip: new wire protocol + Watch local store + merge on both sides
*(The atomic correctness stage. Watch local-store and the new protocol must land together —
a locally-storing Watch on the old action protocol would double-log.)*
- Reshape `Shared/SyncedState.swift` → `SyncSnapshot { events, lastClearedAt,
  amenAlarmFireAt }`; add small `event` and `clear` payloads.
- Watch: lightweight Codable event store + last-synced alarm interval persisted;
  `WatchSessionViewModel` store-backed (sendPray writes a watch-origin event locally →
  instant display + timer reset offline → enqueues for sync); same SyncEngine/derivations.
- Rewrite both `*ConnectivityManager` around send-event / send-clear / send-snapshot /
  receive-and-merge. Snapshot exchange replies with own snapshot. **Delete** the retired
  `sentAt` ordering, count-guard, and action-buffering.
- Amen alarm recomputed from local max; recomputed again on merge.
- **Verify:** unit tests; **real paired iPhone+Watch** for cross-device (see §14, scenarios
  A–F).

### Stage 4 — Re-integrate + re-wire the "SYNCING WITH WATCH" dialog
- Port the takeover UI from branch `admiring-raman` (commits `c3aafce`/`4c7f669`, doc
  `WatchSyncIndicator_Proposal.md`) into `main`.
- **Re-wire its trigger** to the new merge / `WCSession.hasContentPending` flow (it was built
  against the old burst-delivery window).
- Keep the `#if DEBUG` "TEST SYNC" button (sim-testable visuals) + min-display / timeout.
- **Verify:** scenarios A/B/C of the dialog on real devices (§14 group I); visuals via
  `#Preview` + the debug button on the sim.

### Stage 5 — Sync Up Settings row + Settings UI tweaks
- `PhoneConnectivityManager`: observable `isWatchAvailable` (`isPaired &&
  isWatchAppInstalled`, updated on activation + watch-state-change) + `forceSync()`.
- `SettingsView`: add the "Tap to Force Watch Sync" / "Sync Up" row (grayed when
  unavailable); **hide** Save-Log-to-Notes; **fix padding** on Share-with-a-Friend;
  **indent** Privacy Policy to align with Anonymous Analytics; make the frame **scroll
  internally**. Inject the manager via `ContentView` per the existing pattern.
- **Verify:** Maestro/preview for the UI; real-device for Sync Up convergence + graying.

### Stage 6 — Analytics verification + cleanup + build bump
- Assert (tests + PostHog project 210049) each prayer = exactly one `prayer_logged`, correct
  `device_source`, true timestamp, **no double-count after merges**; Watch offline prayers
  arrive late-but-correct.
- Remove dead code from retired patches; final pass.
- Bump build number **iOS + Watch in sync** for a fresh TestFlight build; full real-device
  regression pass (§14).

---

## 14. Comprehensive test plan

### Unit (Simulator / CI — `xcodebuild test`, iOS scheme)
- **SyncEngine:** union+dedupe; idempotency (apply same snapshot twice = no change);
  commutativity (A⊕B == B⊕A); clear-wins pruning (events ≤ clearedAt removed); post-clear
  prayers form the new session; `max(clearedAt)` wins; origin preserved; timer = max active
  timestamp.
- **SessionViewModel:** `logPrayer` appends a phone-origin event; `clearLog` sets epoch +
  prunes + idle; `appState`/`sortedEntries` derived correctly; **analytics emitted once on
  local action, never on merge.**

### Single-device (Simulator + Maestro / `#Preview`)
- Phone-only: log → log grows + timer resets; clear → idle.
- Watch-only **local** display (no connectivity needed for the local store): log on the watch
  sim → local log + timer update.
- Settings UI: Sync Up row present + grayed state; Save-Log-to-Notes hidden; Share padding;
  Privacy Policy indent; frame scrolls. Drive via Maestro / inspect via `#Preview`.
- Dialog visuals via `#Preview` + the `#if DEBUG` "TEST SYNC" button.

### Real paired iPhone + Watch (REQUIRED — sim can't do `transferUserInfo`)

**A. Connected baseline**
1. Log on phone → appears on watch within a moment; timers match.
2. Log on watch → appears on phone; timers match.
3. Clear on either → both go idle.

**B. Disconnected independent logging** (airplane / out of range)
4. Disconnect; log A,B on phone and C,D on watch → each device shows ONLY its own growing
   log + resetting timer.
5. Reconnect → both show union A,B,C,D ordered by time; timer on both = since latest (D);
   takeover dialog covers the reconcile.
6. Origin tag correct (verify via debug/log now; via PostHog `device_source` in group G).

**C. Phone fully off (headline use case)**
7. Power phone off / drain battery. On the watch alone over time: log several prayers → log
   grows, timer keeps running, Amen alarm fires on the watch from its local max using the
   last-synced interval.
8. Power phone back on → reconnect → phone shows the watch's prayers merged; timer correct;
   dialog covers it.

**D. Clear across the gap (destructive rule)**
9. Disconnected: clear on watch at T; phone had a prayer before T, watch logs one after T →
   reconnect → pre-T wiped on both; post-T prayer is the new session on both.
10. Symmetric: clear on phone at T; watch logged before and after T → same result.
11. Both clear independently → later `clearedAt` wins; only prayers after it survive.

**E. Idempotency / robustness**
12. Run B, then force-quit one app mid-delivery, relaunch → no duplicates, no loss, no wedge.
13. Repeated Sync Up taps → converges, no duplicates.
14. Watch app not installed → Sync Up row grayed; phone works normally.
15. Fresh install (data wiped) → clean empty state on both devices.

**F. Amen alarm**
16. Offline watch alarm fires from local max.
17. On merge, a later phone prayer pushes the alarm later on both (recomputed).
18. Duration/enabled change propagates while connected.

**G. Analytics (post-run, PostHog project 210049)**
19. Each prayer = exactly one `prayer_logged`, correct `device_source`, true timestamp; no
    double-count after merges; watch offline prayers arrive late but correctly stamped.

**H. Sync Up**
20. After a disconnect+reconnect, Sync Up forces immediate convergence.

**I. "SYNCING WITH WATCH" dialog (the kept takeover)**
21. Scenario A: phone had active session, watch logged more offline → takeover during sync;
    full log after.
22. Scenario B: phone idle, **session started on the watch** offline → takeover scaffold
    (title only, no timer) during sync; active screen + log after.
23. Scenario C: phone active, watch **cleared** offline → takeover during sync; welcome after.
24. Min display (~1–1.5s), timeout (~8–10s), controls grayed/inert during sync; a normal
    reconnect with nothing queued shows nothing.
</content>
