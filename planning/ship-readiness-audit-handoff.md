# Ship-Readiness Audit — Execution Handoff

> For the next AI agent running **locally** (has Xcode + macOS + `wrangler` + the
> live D1/Worker credentials — things the cloud session that wrote this did not).
> Everything code-side is already committed and pushed. Your job is to
> **verify the build, run the tests, and do the two deploy-time steps below.**

**Branch:** `claude/project-ship-readiness-audit-lp4lhy` (already pushed to origin)
**Commits added on top of `5324f03`:**
- `0a82335` — app-side sync/alarm/analytics fixes (Swift)
- `66ec43f` — waitlist Worker hardening (JS)

**No PR has been opened** — the human (Eric) asked to verify the build first.
Do **not** open a PR unless he explicitly asks.

---

## ⚠️ Do these two things — they are the only unfinished work

### 1. Build + test the iOS/Watch app in Xcode (BLOCKING before any archive)

The Swift changes were written and reviewed in a Linux container with **no Xcode**,
so they are *not yet compiled*. Verify before trusting them:

```sh
# iPhone unit tests (the only test target; watch is compile-only)
xcodebuild test -project "Graces Holy Bell.xcodeproj" -scheme "Graces Holy Bell" \
  -destination 'platform=iOS Simulator,id=<an iOS 26.x sim UDID>'

# Watch target must still compile
xcodebuild build -project "Graces Holy Bell.xcodeproj" \
  -scheme "Graces Holy Bell Watch App Watch App" \
  -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO
```

If anything fails to compile, fix it in place (the logic is described below so you
can tell a real bug from a typo). Expected new/changed tests that must pass:
- `AnalyticsViewModelIntegrationTests` — merge now EMITS watch analytics
  (the old "merge emits nothing" tests were rewritten; see fix #4).
- `SessionArchiveTests` — deterministic id + idempotent append.
- `SyncSnapshotTests` — `watchAlarmInterval` round-trip + `EventMessage`
  tombstone/note round-trip.
- `SessionViewModelTests` / `PrayerLogEditingTests` — set
  `viewModel.prayerDebounceInterval = 0` in setup (already done) so back-to-back
  `logPrayer()` calls in tests aren't swallowed by the new debounce.

**Manual smoke test (most important one):** on a phone+watch pair, turn the Watch
Amen Alarm **ON**, sync, then turn it **OFF**. Confirm the Watch actually stops —
its progress bar disappears and it no longer buzzes. That was the #1 shipping bug.

### 2. Apply the Worker DB migration AFTER deploying the waitlist Worker

The new signup rate-limiter reads/writes a new `rate_events` table. The Worker
**fails open** — if the table is missing, signups still work but the rate limit
silently does nothing. So after `wrangler deploy`, run once:

```sh
cd waitlist
npx wrangler d1 execute grace-waitlist --remote --file=./schema.sql
```

`schema.sql` uses `CREATE TABLE IF NOT EXISTS`, so it's safe to re-run and won't
touch existing `signups` / `ref_clicks` data.

Worker tests already pass locally (no account needed):
```sh
cd waitlist && npm test    # 27 tests, all green
```

---

## What each fix does (so you can review, not just trust)

### App-side (commit `0a82335`)

1. **Watch Amen Alarm can now be turned OFF** *(ship blocker)*
   - `Shared/SyncedState.swift`: `SyncSnapshot` gains `watchAlarmInterval:
     TimeInterval?` (nil = alarm disabled). Optional-with-default so older
     payloads still decode.
   - `SessionViewModel.makeSnapshot`: sets it from the phone's actual setting.
   - `WatchSessionViewModel.applySnapshot`: applies it **authoritatively** every
     snapshot (including clearing it to nil). Previously it *inferred* the
     interval from `amenAlarmFireAt`, which can't tell "disabled" from "idle",
     so a stale saved interval kept re-arming the alarm forever.

2. **Watch prayers are counted in analytics** *(was: totally uncounted)*
   - `SessionViewModel.mergeIncoming`: now emits `session_started` /
     `prayer_logged` / `session_ended` for genuinely-new watch-origin events and
     remote Watch clears, tagged `device_source = watch`, backdated to the true
     prayer times. Logic lives in the new private `MergeAnalytics` struct +
     `emitMergeAnalytics`. Echoes of events the phone already has never re-emit;
     duplicate clears can't double-close (existing no-double-close guard).
   - **Known caveat (documented, accepted):** a watch prayer whose clear reaches
     the phone *before* the prayer itself gets pruned by the epoch and goes
     uncounted. FIFO `transferUserInfo` makes this rare; counting it would risk
     double-counting stale echoes. Noted in `analytics-implementation-status.md`.

3. **Session archive is idempotent** *(prevents duplicate/lost history)*
   - `Models/SessionArchive.swift`: `ArchivedSession.deterministicID(...)` hashes
     the prayer timestamps (SHA-256 → UUID); `SessionArchiveStore.append` skips
     an id it already holds. The old `archiveRemotelyEndedSession` helper was
     folded into `mergeIncoming` so the remote-clear archive and analytics come
     from one code path. History is still behind `FeatureFlags.prayerHistoryEnabled`
     (off), so this hardens data that's accruing for when it's turned on.

4. **`EventMessage` carries `isDeleted` + `note`** *(latent correctness)*
   - `Shared/SyncedState.swift`: the single-event offline wire message used to
     drop these, so a delete/edit sent that way could resurrect a prayer via
     last-writer-wins. Now the full event survives the wire.

5. **1-second PRAY debounce** — `SessionViewModel.logPrayer` and
   `WatchSessionViewModel.sendPray` ignore a second prayer within 1s of the last
   (accidental double-slide → no more 0-second log rows). Phone's interval is a
   `var` so tests can zero it.

6. **`deletePrayer` analytics** — skips the event when the entry isn't in the
   active log, instead of sending a fabricated index 0.

7. **Watch share QR off the main thread** — `WatchShareView` encodes via
   `Task.detached`; `WatchQRCodeView.matrix` marked `nonisolated`. Stops the
   pure-Swift encoder from janking the share screen's entrance animation.

### Waitlist Worker (commit `66ec43f`)

- **Per-IP rate limit** — 5 signups/hour, keyed on a SHA-256 hash of
  `CF-Connecting-IP` (raw IP never stored). New `rate_events` table. Fails open.
- **Duplicate-email suppression** — a repeat email returns `{ok:true}` with no
  new row and no repeat confirmation/admin email (stops using the endpoint to
  spam an address).
- **CSV formula-injection guard** — `csvCell` prefixes a leading `= + - @` /tab
  with `'` so exported attacker text can't execute in Excel/Sheets.
- All in `waitlist/src/index.js`; migration in `waitlist/schema.sql`; coverage in
  `waitlist/test/index.test.js` (+5 tests).

---

## Findings that were intentionally NOT changed

- **30-second "test" Amen Alarm duration** is still shipping in the picker —
  Eric explicitly said keep it for now (`AmenAlarmSettings.swift`,
  `AmenAlarmDuration.testThirtySeconds`).
- **Watch availability flag can flicker** during first pairing — informational
  only; the "Force Watch Sync" row that depends on it is currently hidden.

---

## Quick status checklist for the local agent

- [ ] `xcodebuild test` (iOS) passes
- [ ] `xcodebuild build` (Watch) passes
- [ ] Manual: Watch alarm OFF actually stops the Watch
- [ ] `cd waitlist && npm test` → 27 green
- [ ] Worker deployed, then `wrangler d1 execute ... --file=./schema.sql` run
- [ ] (only if Eric asks) open the PR
