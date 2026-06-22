# AI Handoff Document — Grace's Holy Bell

---

## Session Log

| Date | What Was Done |
|---|---|
| **2026-06-01** | Created `DesignSystem.swift` (both targets), updated `WatchFirstLaunchView.swift` to match Figma node 216:758 (v1.41), updated `ui-workflow.md` with Layout Translation Rules. Left Top Title Block positioning is incomplete — see ⚠️ section below. |

---

## Project Overview

**App:** Grace's Holy Bell — iOS + watchOS prayer tracker with a Game Boy / Tamagotchi LCD pixel-art aesthetic.
**Repo:** `/Users/ericbogin/Developer/graces-holy-bell`
**Active Branch:** `beta-UI`
**Xcode Project:** `Graces Holy Bell.xcodeproj`

**Session goal:** Import Figma designs into the existing app to clean up the UI while preserving all original functional logic — state, timers, ViewModels, bindings. No features added or removed. This is a visual/layout pass only.

---

## ⚠️ Build & Release Gotchas

**Bumping the build number? Bump BOTH targets.** `CURRENT_PROJECT_VERSION`
(the build number / `CFBundleVersion`) appears for multiple targets in
`Graces Holy Bell.xcodeproj/project.pbxproj`. The **iOS app** and the **embedded
Watch app** (`...watchkitapp`) build numbers **must match** — App Store Connect
rejects the upload with a `CFBundleVersion` mismatch otherwise. It's easy to bump
only the iOS app (Xcode's "increment on archive" and manual edits often miss the
Watch target). After any bump, verify all app+watch entries agree:

```
grep -n "CURRENT_PROJECT_VERSION" "Graces Holy Bell.xcodeproj/project.pbxproj"
```

The `GracesHolyBellTests` target never ships, so its value doesn't need to match.
`MARKETING_VERSION` (the user-facing version, e.g. 1.42) is separate from the
build number and changes only on a real release.

---

## Figma File

**File:** Grace's Holy Bell
**URL:** `https://www.figma.com/design/aFFwA2eZWpjhJJVvQIh0Sb/Grace-s-Holy-Bell`
**MCP Server in use:** **Remote Figma MCP** (NOT the Figma desktop plugin).

Tools used: `get_design_context`, `get_screenshot`, `get_metadata`, `get_variable_defs`.

> Always call `get_design_context` AND `get_screenshot` fresh for any node before working — the Figma file has been actively updated during this session and cached results will be stale.

---

## Workflow Rules (Read Before Touching Any File)

Rules file: `.claude/agents/ui-workflow.md`

1. Extract colors/fonts from `DesignSystem.swift` — never hardcode hex values.
2. Never modify `@State`, `@StateObject`, `@EnvironmentObject`, timers, closures, or model bindings.
3. Never modify `WatchPrayingFigureView()` internals. It is an animated figure. Only modify surrounding layout wrappers (`.padding`, `VStack`, `HStack`).
4. Map Figma Auto Layout `item-spacing` → SwiftUI `spacing:` parameter directly. Never use `Spacer().frame(height: X)` for invisible placeholder shapes.
5. **Always present a mapping table and get human approval before modifying any file.**

---

## What Was Completed This Session

### 1. `DesignSystem.swift` — Created (both targets)

- `Graces Holy Bell/DesignSystem.swift` — iOS target ✅
- `Graces Holy Bell Watch App Watch App/DesignSystem.swift` — Watch target ✅ (file exists on disk)

> ⚠️ The Watch copy must be **manually added to the Xcode project**. The file exists on disk but Xcode won't compile it until you do: Project Navigator → right-click Watch App group → Add Files → select `DesignSystem.swift` → ensure only the Watch target is checked.

**Tokens defined:**
- `DesignSystem.Colors` — `background` (#c8d8b0), `backgroundLight`, `backgroundDark`, `surfaceInner`, `surfaceBorder`, `interactive` (#8aaa6a), `textPrimary` (#1a2a0a), `textSecondary` (#4a6a3a), `textOnDark`, `border`
- `DesignSystem.Typography` — `caption`(7), `bodySmall`(8), `body`(9), `bodyLarge`(10), `subheadline`(11), `headline`(12), `display`(28) — all PressStart2P-Regular
- `DesignSystem.Spacing` — `xxs` through `xxxl` (2, 4, 6, 8, 12, 16, 24, 32)
- `DesignSystem.Radius` — `sm`(3), `md`(6), `lg`(8)
- `DesignSystem.Gradients.lcdBackground`

The existing `Theme.swift` in both targets is still live. `DesignSystem.*` and `Color.lcd*` / `.pixelFont()` currently coexist — no call-site migration was done yet.

### 2. `WatchFirstLaunchView.swift` — Partially updated

**File:** `Graces Holy Bell Watch App Watch App/Views/WatchFirstLaunchView.swift`
**Figma node:** `216:758` ("Watch Start - v1.41")

Changes made and confirmed working:
- Slider label: `"START PRAYING"` → `"PRAY"`, `labelPadLeft: true` → `false` (centered, larger font)
- `"SLIDE TO BEGIN"` moved below the slider (matches Figma)
- `Color.lcdDark` → `DesignSystem.Colors.textPrimary`
- `Color.lcdMid` → `DesignSystem.Colors.textSecondary`
- `.background(DesignSystem.Colors.background)` added to root
- Inner `VStack(spacing: 8)` maps Figma's `gap-[17px]` Core Content Stack

**Current state of the file:**
```swift
import SwiftUI
import WatchKit

struct WatchFirstLaunchView: View {

    let viewModel: WatchSessionViewModel
    var namespace: Namespace.ID

    private var figureHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 96 : 86
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("GRACE'S\nHOLY BELL")
                .font(.pixelFont(8))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Text("GRACE'S\nHOLY BELL")
                    .font(.pixelFont(11))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                WatchPrayingFigureView(pose: .idle, height: figureHeight)
                    .matchedGeometryEffect(id: "prayFigure", in: namespace)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            WatchPraySlider(label: "PRAY", labelPadLeft: false) {
                viewModel.sendStart()
            }

            Text("SLIDE TO BEGIN")
                .font(.pixelFont(7))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}
```

---

## ⚠️ Incomplete — Next AI Starts Here

### Problem: Left Top Title Block is in the wrong position

**What the Figma shows (node 216:758):**
The small olive-green "GRACE'S / HOLY BELL" header (`.pixelFont(8)`, `textSecondary`) sits **horizontally inline with the native watchOS system time** — top-left of the screen, same row as the clock.

**What the current code does:**
The small title `Text` is the first child of the outer `VStack`, so it stacks **below** the system time and takes up vertical space in the content area. It renders in the wrong row entirely.

**What needs to happen:**
The Left Top Title Block must appear in the **navigation bar row** — to the left of the system time — not in the scrollable body. This is standard watchOS navigation bar placement.

**Approaches already tried and their outcomes:**
- `.toolbar { ToolbarItem(placement: .principal) }` — **build error**: `principal` is unavailable on watchOS
- `.navigationTitle("GRACE'S HOLY BELL")` — compiles but loses pixel font styling; renders as plain system text

**Recommended next steps:**
1. Check where `WatchFirstLaunchView` is instantiated — search `ContentView.swift` in the Watch target. Determine whether it is inside a `NavigationStack`. If not, toolbar items will not render regardless of placement.
2. Try `ToolbarItem(placement: .confirmationAction)` — this IS available on watchOS and places content in the top-right area. Or `.cancellationAction` for top-left (matching the Figma's left alignment).
3. If adding a `NavigationStack` wrapper is needed, add it at the root Watch `ContentView` level, not inside `WatchFirstLaunchView`.
4. Preserve pixel font: whatever placement works, the text should remain `.font(.pixelFont(8)).foregroundStyle(DesignSystem.Colors.textSecondary)`.

---

## Figma Scale Factor Reference

Figma canvas: `410×502px`. Actual Apple Watch: ~184px wide. Scale ≈ **0.45**.

| Figma value | watchOS SwiftUI equivalent |
|---|---|
| `gap: 4px` | `VStack(spacing: 2)` |
| `gap: 17px` | `VStack(spacing: 8)` |
| `pt: 8px` | `.padding(.top, 4)` |
| `18px` font | `.pixelFont(8)` |
| `24px` font | `.pixelFont(11)` |
| `14px` font | `.pixelFont(7)` |

---

## Known Non-Issues

- **`No such module 'WatchKit'` (SourceKit, line 2 of WatchFirstLaunchView.swift)** — SourceKit indexing warning only. Not a real build error. The build succeeds.

---

## Prior Session Context (from previous HANDOFF.md)

The following bugs were identified in an earlier session and may still apply:

### Bug — Black bar at bottom of some screens
Root VStacks in some Watch views size to content, leaving black space below the LCD-green area.
Fix: `.frame(maxWidth: .infinity, maxHeight: .infinity)` on root VStacks. Already applied to `WatchFirstLaunchView`.

### Bug — System clock + battery showing in upper left
`.ignoresSafeArea()` does not suppress watchOS persistent system overlays.
Fix: Add `.persistentSystemOverlays(.hidden)` (watchOS 9+) to the root ZStack in `ContentView.swift`.

### Bug — Praying figure jumps when switching First Launch → Active
`matchedGeometryEffect(id: "prayFigure", in: namespace)` is already applied to `WatchFirstLaunchView`. Verify it is also applied to `WatchActiveSessionView` with the same namespace passed from the parent.

---

## Key Files Reference

| File | Purpose |
|---|---|
| `Graces Holy Bell Watch App Watch App/ContentView.swift` | Root Watch view — ZStack + route switch |
| `.../Views/WatchFirstLaunchView.swift` | **Active work target** — Watch Start screen |
| `.../Views/WatchActiveSessionView.swift` | Active prayer session screen |
| `.../Views/WatchLogView.swift` | Prayer log screen |
| `.../Views/WatchIdleClearedView.swift` | Post-session idle screen |
| `.../Views/WatchPraySlider.swift` | Slide-to-confirm control (`labelPadLeft` param controls centering) |
| `.../Views/WatchPrayingFigureView.swift` | Animated pixel figure — do not modify internals |
| `Graces Holy Bell Watch App Watch App/DesignSystem.swift` | Design tokens — needs adding to Xcode target |
| `.claude/agents/ui-workflow.md` | Mandatory workflow rules |
