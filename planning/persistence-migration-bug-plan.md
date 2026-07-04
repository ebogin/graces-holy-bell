# 1.42 iPhone persistence bug — root cause + fix plan

> **Status (2026-07-03): FIXED, pending TestFlight confirmation.** Implemented as
> planned (PrayerSchema.swift V1/V2 + migration plan, explicit container with
> recovery fallback in Graces_Holy_BellApp, persistence_error analytics, logged
> save/fetch). All 160 unit tests pass incl. 4 new migration tests; sim E2E
> verified: seeded 1.41 store migrates cleanly (row kept, unique id, origin=phone),
> writes survive force-kill, relaunch loads them. Build bumped to 1.42 (17).

**Reported:** Jul 3, 2026 (beta user, iPhone 15 Pro Max / iOS 26.5, build 1.42 (16)).
Prayer log resets whenever the app process dies (force quit or OS background kill).
Reproducible on Eric's device too. Started with the 1.42 Watch-sync-refactor builds.

## Root cause (verified)

The Stage 2 phone rewrite (commit `402ab7c`) added two **mandatory** properties to the
SwiftData `PrayerEntry` model with no schema-level default values:

- `var id: UUID` (new)
- `var origin: String` (new)

Defaults exist only in `init(...)`, which SwiftData does **not** put in the Core Data
schema. On any device whose store was created by 1.41 **and contains at least one
PrayerEntry row**, lightweight migration fails on every launch:

```
NSCocoaErrorDomain 134110 — Cannot migrate store in-place:
Validation error missing attribute values on mandatory destination attribute
(entity=PrayerEntry, attribute=id)
```

Verified two ways:
1. CLI harness (old-schema store → open with new schema): container creation throws.
2. Real app in the iOS 26.5 simulator with a 1.41-schema store seeded into its
   container: same CoreData 134110 error at launch, **app does not crash** —
   `.modelContainer(for:)` leaves the app running with a store that never loaded.

Downstream mechanism (SessionViewModel.swift):
- `load()` uses `try? modelContext.fetch(...) ?? []` → silently returns empty.
- `save()` uses `try? modelContext.save()` → silently fails.
- Inserts live only in the in-memory context, so the UI works fine *within* a run;
  everything vanishes at process death. Exactly the reported symptom.

Why we never saw it in dev: every fresh install (simulator, new TestFlight device)
creates the store with the *new* schema directly — only devices that upgraded from
1.41 with prayer rows on disk are affected. Migration failure is non-destructive:
affected users' pre-1.42 store is still intact on disk, old-schema.

Watch app is unaffected (plist-based `WatchEventStore`, not SwiftData).
`lastClearedAt` (UserDefaults) is unaffected.

## Fix plan

### 1. Versioned schema + migration plan (the real fix)
- Define `GHBSchemaV1` (1.41 models: PrayerEntry{timestamp, sequenceIndex, session},
  PrayerSession) and `GHBSchemaV2` (current models) as `VersionedSchema`s.
- In V2, give the new attributes schema-level defaults so structural migration can
  populate old rows: `var origin: String = "phone"`, `var id: UUID = UUID()`.
- `SchemaMigrationPlan` V1→V2 with a **custom stage** whose `didMigrate` walks
  migrated PrayerEntry rows and reassigns a *unique* `UUID()` per row (a constant
  schema default could stamp duplicate ids, which would break cross-device dedup)
  and sets `origin = "phone"`.
- Build the container explicitly in `Graces_Holy_BellApp.init` with
  `ModelContainer(for:migrationPlan:configurations:)` and inject via
  `.modelContainer(container)` instead of `.modelContainer(for:)`.

### 2. Last-resort fallback — never strand a dead store again
- If container creation still throws (any future migration bug), log the error,
  destroy the store files (`default.store`, `-wal`, `-shm`), and recreate a fresh
  container. Losing the (ephemeral, usually small) log once is strictly better than
  silently losing all writes forever.

### 3. Stop swallowing persistence errors
- Replace `try?` on fetch/save in SessionViewModel with do/catch + `os_log` fault,
  and emit an analytics event (e.g. `store_save_failed` / `store_load_failed`,
  labels-only) so silent data loss is observable in PostHog next time.

### 4. Effects on affected users after the fix ships
- Their 1.41-era rows migrate and reappear — but `prayer.lastClearedAt` (UserDefaults)
  was updated during 1.42 use, so `pruneAndRefresh()` deletes the stale pre-clear rows
  on first load. Most users just see a working app again.
- Prayers logged while on 1.42 were never written to disk; unrecoverable. Tell John.

### 5. Verification
- Unit test: build a V1 store, open with the migration plan, assert row count kept,
  unique ids, origin == "phone".
- Sim E2E (already-seeded repro): iPhone 17 Pro sim `76B338B2-F15E-48DD-B71F-A8A384C06D8F`
  has the app installed with a 1.41-schema store containing a prayer row (fixture:
  scratchpad migrationtest/store.sqlite). Install fixed build over it → launch → no
  CoreData 134110 in logs → log a prayer → `simctl terminate` → relaunch → prayer
  still there.
- Bump iOS build number (and matching Watch target build — App Store upload fails
  otherwise), TestFlight to John for confirmation.
