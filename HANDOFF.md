# Handoff: Grace's Holy Bell — Watch UI Layout Fixes

## Project
iOS + watchOS SwiftUI app. Working directory / git worktree:
`/Users/ericbogin/Developer/graces-holy-bell/.claude/worktrees/hungry-bohr-6b8a62`
Branch: `claude/hungry-bohr-6b8a62`

## What's done
A new pixel-art LCD-green watch UI was implemented across 4 screens:
- `WatchFirstLaunchView` — idle figure + START PRAYING slider
- `WatchActiveSessionView` — live timer + praying animation + PRAY slider + STOP/LOG buttons
- `WatchLogView` — timer + scrollable log + BACK button
- `WatchIdleClearedView` — title + timestamp + scrollable log + CLEAR button

Build compiles clean:
```
xcodebuild -scheme "Graces Holy Bell Watch App Watch App" \
  -destination "platform=watchOS Simulator,id=6ED128C1-FD25-4334-8C5E-FC52A0AE65CA" build
```

## Three remaining bugs (NOT yet fixed)

### Bug 1 — Black bar at bottom of First Launch and Active screens
**Root cause:** The root VStacks in `WatchFirstLaunchView` and `WatchActiveSessionView` size to content, leaving unused space that shows as black below the LCD-green area.

**Fix:** Add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to the root `VStack` in both views. Apply the same to `WatchLogView` and `WatchIdleClearedView` for consistency.

```swift
// Example — add this to each screen's root VStack:
VStack(spacing: 0) { ... }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
```

### Bug 2 — System clock + battery indicator showing in upper left
**Root cause:** `.ignoresSafeArea()` does not suppress watchOS persistent system overlays. The correct API is `.persistentSystemOverlays(.hidden)` (watchOS 9+).

**Fix:** In `ContentView.swift`, add `.persistentSystemOverlays(.hidden)` to the root ZStack:

```swift
ZStack {
    Color.lcdBackground
    switch viewModel.route { ... }
}
.ignoresSafeArea()
.persistentSystemOverlays(.hidden)   // ← ADD THIS
.onReceive(connectivityManager.$latestState) { ... }
```

### Bug 3 — Praying figure jumps position when switching First Launch → Active
**User request:** "When a user switches to the ACTIVE screen, and the animation starts, the animation should be in the exact same place as the image on the FIRST LAUNCH screen."

**Root cause:** The two screens have different VStack layouts, so the figure lands at a different Y position.

**Fix options:**
- **Option A (recommended):** Use `matchedGeometryEffect` with a shared `Namespace` passed down from `WatchContentView`, keying the figure view on both screens to the same ID so SwiftUI animates it smoothly between positions.
- **Option B:** Make both layouts distribute vertical space identically so the figure's center is at the same absolute Y — harder to maintain.

For Option A, thread a `@Namespace` from `WatchContentView` into `WatchFirstLaunchView` and `WatchActiveSessionView`, then apply:
```swift
WatchPrayingFigureView(pose: .idle, height: figureHeight)
    .matchedGeometryEffect(id: "prayFigure", in: namespace)
```
on First Launch, and:
```swift
WatchPrayingFigureView(pose: .praying, height: figureHeight)
    .matchedGeometryEffect(id: "prayFigure", in: namespace)
```
on Active. Wrap the `switch` in `WatchContentView` with a `withAnimation` block on route change.

## Key files

| File | Purpose |
|------|---------|
| `Graces Holy Bell Watch App Watch App/ContentView.swift` | Root view — ZStack + route switch. Fix Bug 2 here. |
| `.../Views/WatchFirstLaunchView.swift` | First launch screen. Fix Bugs 1 & 3 here. |
| `.../Views/WatchActiveSessionView.swift` | Active session screen. Fix Bugs 1 & 3 here. |
| `.../Views/WatchLogView.swift` | Log screen. Fix Bug 1 here. |
| `.../Views/WatchIdleClearedView.swift` | Idle/cleared screen. Fix Bug 1 here. |
| `.../Views/WatchLiveTimerView.swift` | Timer display — already fixed (adaptive font size). |

## Design reference
Original Figma handoff was exported to: `/tmp/grace-s-holy-bell/` (may not persist). The LCD color palette:
- `lcdBackground` / `lcdBg` — `#c8d8b0`
- `lcdDark` — `#1a2a0a`
- `lcdMid` — `#4a6a3a`
- `lcdThumbText` — `#c8d8b0`

## Notes
- Font: Press Start 2P (registered programmatically at launch, `.pixelFont(n)` extension)
- Watch size detection: `WKInterfaceDevice.current().screenBounds.width >= 200` → 49mm Ultra
- `@Observable` macro used (not `@Published`) — bare `var` properties
- Simulator ID for Apple Watch Ultra 3 49mm: `6ED128C1-FD25-4334-8C5E-FC52A0AE65CA`
