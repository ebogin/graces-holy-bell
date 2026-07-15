# Handoff — Building the Per-Prayer Figure Animations

**Audience:** the AI (or person) building the actual figure animations.
**Status:** all the *plumbing* is built and verified (phone + watch compile and
run). What's left is the **art**: each prayer action currently renders a
placeholder, and your job is to replace that placeholder with the real
animation, keyed off a stable action `id`.

Read [ANIMATIONS.md](ANIMATIONS.md) first — it's the remote-config contract
(schema + how to publish sequences without a build). This doc is the code map.

---

## 1. The idea, in one paragraph

During a prayer session the figure normally loops a 4-frame "praying" sprite in
a fixed slot on screen. Now, after each PRAY swipe, the app plays a short
**action** in that same slot for a few seconds, then returns to praying. The
**N-th swipe plays the N-th action** in a remotely-configured, ordered
sequence (e.g. #1 *kneel*, #2 *walk to a door*, #3 *step outside*). The
sequence and per-action durations come from the `animations` remote config; the
figure returns to praying when each action's time is up.

Today each action draws a **large "#N" + a small rotating dashed ring + the
action's `id`** as a stand-in. You're replacing that stand-in.

---

## 2. What already works (don't rebuild these)

- **Remote config** — an ordered `actions` list is fetched from `/app-config`,
  cached, with a bundled fallback, on **both** phone and watch. Publish new
  sequences with a `curl` (ANIMATIONS.md). No Worker change needed.
- **Index selection** — the N-th swipe resolves to the N-th action; past the end
  of the list the figure just keeps praying. First swipe (which starts the
  session from the idle screen) correctly triggers action #1.
- **Timing** — each action shows for its `durationSeconds` (default 5), then the
  figure returns to praying. A rapid subsequent swipe interrupts and restarts.
- **The figure slot** — placeholder and real figure share the exact same
  position and footprint on both platforms, so nothing on screen jumps.

You should not need to touch the trigger, the config, or the layout wiring
unless you're changing the *timing model* (see §6).

---

## 3. Files — the whole feature

Shared:
- **`Shared/PrayerActionsConfig.swift`** — the manifest model (`PrayerActionsConfig`,
  `PrayerAction`, `ResolvedPrayerAction`) + `action(forPrayerIndex:)` selection
  + `bundledDefault`. Shared by both targets. **`ResolvedPrayerAction` is what
  the views render** — it carries `prayerIndex`, `actionID`, `durationSeconds`,
  `label`.

iPhone:
- **`Graces Holy Bell/Views/PrayerActionView.swift`** — ⭐ THE PLACEHOLDER. Replace
  its `body` with the real animation. Sized to the praying figure's footprint
  (50×63 pt × `scale`, `scale` defaults to 2.6 → 130×164 pt).
- `Graces Holy Bell/Views/PrayingFigureView.swift` — the existing praying sprite
  (reference for how sprite animation is done here).
- `Graces Holy Bell/Views/PrayerScreenLayout.swift` — figure slot; swaps in
  `PrayerActionView` when an action is active (`if let prayerAction { … }`).
- `Graces Holy Bell/Views/ActiveSessionView.swift` — the trigger
  (`syncPrayerAction()`, `onAppear`/`onChange`, `.task(id:)` auto-clear).
- `Graces Holy Bell/RemoteConfig.swift` — decodes the `animations` key; exposes
  `currentPrayerActions`.
- `Graces Holy Bell/FeatureFlags.swift` — `prayerActionsEnabled` (phone gate).
- `Graces Holy Bell/ContentView.swift` — passes `remoteConfig` to
  `ActiveSessionView`; gates the fetch.

Apple Watch (mirrors the phone):
- **`…Watch App/Views/WatchPrayerActionView.swift`** — ⭐ THE WATCH PLACEHOLDER.
  Replace its `body` too. Sized by `height` (the slot height the layout passes).
- `…Watch App/Views/WatchPrayingFigureView.swift` — existing watch sprite
  (aspect 563:711).
- `…Watch App/Views/WatchScreenLayout.swift` — watch figure slot; swaps in
  `WatchPrayerActionView`.
- `…Watch App/Views/WatchActiveSessionView.swift` — watch trigger.
- `…Watch App/Utilities/WatchAnimationConfigStore.swift` — watch's own fetch of
  the manifest.
- `…Watch App/ContentView.swift` — owns/refreshes the store; passes it down.

Docs: `ANIMATIONS.md` (remote-config contract), this file.

---

## 4. The contract you build against

Each placeholder view is handed one value:

```swift
struct ResolvedPrayerAction {
    let prayerIndex: Int       // 1-based: which swipe this is (drives "#N")
    let actionID: String       // ⭐ your art hook, e.g. "kneel", "walk-to-door"
    let durationSeconds: Double // how long you have before returning to praying
    let label: String          // placeholder caption ("#N"); ignore for real art
}
```

**Key off `actionID`.** The remote config author picks these ids (ANIMATIONS.md);
they're stable identifiers, exactly like asset names. Your job: given an
`actionID`, render the right animation, for ~`durationSeconds`, in the slot.

A convention that fits this codebase well: **sprite frames in the asset
catalog, named per action** — e.g. `kneel_frame_1…kneel_frame_n` — and animate
them the way `PrayingFigureView` animates `pray_frame_1…4` (a `Task` that cycles
frames on an interval). Then `PrayerActionView` becomes: look up
`"\(actionID)_frame_\(i)"`, cycle for the duration. But you're free to choose
another representation (a single multi-pose strip, SwiftUI-drawn shapes, etc.).

---

## 5. How to add artwork assets (no Xcode project edits)

Both app targets use **synchronized file groups**, so **new files in the
target's folders are picked up automatically — no `.pbxproj` editing.**

- iPhone assets: drop imagesets into
  `Graces Holy Bell/Assets.xcassets/…` (see the existing `pray_frame_1.imageset`
  for the `Contents.json` shape; use `"interpolation": "none"`-equivalent by
  keeping pixel art at the right scale — the views set `.interpolation(.none)`).
- Watch assets: `Graces Holy Bell Watch App Watch App/Assets.xcassets/…`
  (the watch needs its **own** copy of each imageset — assets are not shared
  across targets even though `Shared/*.swift` code is).
- New Swift files: anywhere under the target's folders (or `Shared/` for
  cross-target code) — auto-included.

Pixel-art style: dark figure on transparent background, rendered over the LCD
green. Keep frames crisp (the views disable interpolation). Match the existing
`pray_frame_*` art's palette and scale.

---

## 6. Design decisions you might want to revisit

These were chosen for the scaffolding; each is easy to change and localized.

1. **Timing is manifest-driven, not animation-driven.** The figure returns to
   praying after `durationSeconds`, regardless of your animation's natural
   length. Design each action to read well within its configured duration — or,
   if you want the *animation* to decide when it's done, change the auto-clear
   in `ActiveSessionView.swift` / `WatchActiveSessionView.swift` (the
   `.task(id: activeAction)` block) to clear on an animation-completion callback
   instead of `Task.sleep`.
2. **Selection clamps then stops.** Past the last action, the figure just prays.
   To loop or hold the last pose, edit only
   `PrayerActionsConfig.action(forPrayerIndex:)`.
3. **The Watch fetches the manifest directly** (its own `URLSession`), rather
   than receiving it from the phone over WatchConnectivity. This keeps the
   scaffolding off the sync/`SyncedState` surface. If you'd rather the phone be
   the single fetcher and push the manifest to the watch, that's a
   `SyncSnapshot` field + a line in the connectivity managers — but note those
   files are also touched by the ongoing bell branch (see §8), so coordinate.
4. **The Watch has no feature flag.** `FeatureFlags.prayerActionsEnabled` gates
   the phone only. To gate both from one switch, move `FeatureFlags.swift` into
   `Shared/` (it's pure constants) and reference the flag in
   `WatchActiveSessionView.syncPrayerAction()`.
5. **Replay guard.** Actions only play for a prayer logged within the last 3 s,
   so relaunching into an active session (or returning from a sheet) doesn't
   replay the last action. If you make actions animation-driven, keep this in
   mind. Constant: `actionTriggerRecency`.
6. **Placeholder is deliberately non-representational** (a rotating dashed ring,
   not a little person) so it never gets mistaken for real art. Delete it
   wholesale when you drop in the real thing.

---

## 7. How to test

Build & run (schemes): `Graces Holy Bell` (iPhone),
`Graces Holy Bell Watch App Watch App` (watch). Both currently build clean.

Exercise it:
1. Launch, swipe **PRAY** to start → you should see **#1** appear in the figure
   slot for ~5 s, then the figure resumes praying.
2. Swipe again → **#2**, then **#3**, #4, #5 (the bundled default has 5). The
   6th swipe onward: no action, just praying (past the sequence end).
3. Swipe rapidly → the placeholder jumps to the newest #N immediately.
4. Remote test: publish a sequence per ANIMATIONS.md, force-quit/relaunch after
   the cache windows, and confirm your ids/durations take effect. The `id`
   shown under each "#N" tells you which action resolved.

There's a DEBUG prayer-log seeding hook in `ContentView` (`seedPrayerLogIfRequested`)
if you want to jump straight into an active session with history.

Per the repo owner's workflow: **write code and open it in the simulator, then
pause for a human to visually verify** — don't self-verify UI via screenshots.

---

## 8. Branch context (so your work merges cleanly)

This branch = `main` + the on-hold **AMEN full-screen takeover** (bell tower)
merged in. A sibling branch, `claude/watch-bell-ringing-sound-animation-f9cb19`,
is the *ongoing* home of that bell/AMEN work and will merge with this later. It
touches `ActiveSessionView`, `WatchActiveSessionView`, the session view models,
`SyncedState`, and the connectivity managers — so this scaffolding deliberately
concentrates changes in files that branch does **not** touch
(`PrayerScreenLayout`, `PrayingFigureView`, `WatchScreenLayout`,
`WatchPrayingFigureView`, `RemoteConfig`, and the new files). Keep your artwork
changes in `PrayerActionView` / `WatchPrayerActionView` / new asset files and
you'll stay out of the merge path too.

`main` is untouched by all of this.
