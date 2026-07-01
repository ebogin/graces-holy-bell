# Implementation Plan: Inset corner buttons on rounded-display Apple Watches

## Goal
The bottom-row corner buttons (lower-left / lower-right) get clipped by the curved glass on
the more-rounded watch displays. Push each corner button **horizontally toward the center** by
an amount **proportional to how much more rounded that model is than the Apple Watch SE**, then
fine-tune the scale factor visually in the simulator. Centered buttons (the Stop octagon on the
Active screen) and everything else on screen must not move or resize.

### Model (locked with product owner)
- **Baseline = radius 28 → offset 0.** The SE (40mm, radius 28pt) renders correctly today with
  no inset, so radius 28 is the zero point.
- **Offset is proportional to radius above that baseline:**
  `offset = max(0, cornerRadius − 28) × cornerInsetScale`
  where `cornerInsetScale` is a single tunable constant, dialed in by eye (see Step 4).
- **Horizontal (x-axis) movement only.** Never change any button's y-position or size.
- **Iterative:** the exact `cornerInsetScale` is set by looking at the Series 11 and Ultra in-sim
  and adjusting until it looks right — see the tuning loop in Step 4.

### Verified corner radii (extracted from Figma "Display Shapes" community file, in points)
Radii are in the **same unit as the screen point sizes** (confirmed: SE 40mm is 162×197 @ radius 28),
so no px→pt conversion. Every screen width maps to exactly one radius (no collisions).

| Model | Screen W×H (pt) | Radius | Offset = (r−28)×scale |
|---|---|---|---|
| SE 1/2/3 40mm, Series 4/5/6 40mm | 162 × 197 | 28 | 0 (baseline) |
| SE 1/2/3 44mm, Series 4/5/6 44mm | 184 × 224 | 34 | (r−28)=6 |
| Series 7/8/9 41mm | 176 × 215 | 38 | 10 |
| Series 7/8/9 45mm | 198 × 242 | 41 | 13 |
| Series 10/11 42mm | 187 × 223 | 45 | 17 |
| Series 10/11 46mm | 208 × 248 | **49** | 21 |
| Ultra 1/2 49mm | 205 × 251 | 54 | 26 |
| Ultra 3 49mm | 211–212 × 257 | **56** | 28 |
| Series 0–3 (38/42mm) | 136×170 / 156×195 | 0 | 0 |

("Offset" column shows the *pre-scale* delta `r−28`; multiply by `cornerInsetScale` for the actual pt shift.)

## Background: why the earlier attempts failed (do NOT repeat them)
- Deriving the inset from `GeometryReader.safeAreaInsets` (an `EnvironmentKey` called
  `watchBezelInsets`) produced ~0 everywhere: watchOS reports a constant ~2pt horizontal safe-area
  inset on every model, so it does not encode corner curvature.
- There is **no public watchOS API for corner radius** (`_displayCornerRadius` is private → App Store
  risk; do not use it). Identify the model by `WKInterfaceDevice.current().screenBounds` width — a
  stable per-model constant — and map to the radius table above.

## Step 0 — (already done) tree is clean of the failed approach
An earlier experiment plumbed a `watchBezelInsets` `EnvironmentKey` (derived from
`safeAreaInsets`) through `ContentView`, `DesignSystem`, `WatchScreenLayout`, `WatchLogView`,
and `WatchShareView`. That approach did not work (see Background) and has been fully removed —
the current `main` contains none of it, and the already-approved UI tweaks (see "Do not regress")
are intact. There is nothing to undo; start at Step 1.

## Step 1 — Radius + inset in DesignSystem
In **`DesignSystem.swift`**, inside `enum DesignSystem.Metrics` (the file already imports `WatchKit`):

```swift
/// Tunable scale for the corner-button inset. Multiplied by how many points a
/// model's display corner radius exceeds the SE baseline (28pt). Set by eye in
/// the simulator on the Series 11 and Ultra — see the tuning loop in the plan.
/// Starting point: 0.7 (→ Ultra 3 ≈ 20pt, Series 11 46mm ≈ 15pt).
static let cornerInsetScale: CGFloat = 0.7

/// Documented display corner radius (points) keyed by screen width. The SE
/// baseline is 28. watchOS exposes no corner-radius API, so we look it up from
/// screenBounds (a stable per-model constant). Unknown widths fall back to 28
/// (→ zero inset), which is safe.
static var displayCornerRadius: CGFloat {
    switch WKInterfaceDevice.current().screenBounds.width {
    case 161...163: return 28   // 40mm (SE 1/2/3, Series 4/5/6)
    case 183...185: return 34   // 44mm (SE 1/2/3, Series 4/5/6)
    case 175...177: return 38   // 41mm (Series 7/8/9)
    case 197...199: return 41   // 45mm (Series 7/8/9)
    case 186...188: return 45   // 42mm (Series 10/11)
    case 207...209: return 49   // 46mm (Series 10/11)
    case 204...206: return 54   // 49mm (Ultra 1/2)
    case 210...213: return 56   // 49mm (Ultra 3)
    default:        return 28   // older/square + anything unknown → no inset
    }
}

/// Horizontal shift applied to each lower-left / lower-right corner button so it
/// clears the rounded display corner. Zero at the SE baseline; grows with radius.
static var cornerButtonInset: CGFloat {
    max(0, displayCornerRadius - 28) * cornerInsetScale
}
```

## Step 2 — Apply the inset to each corner-button row
Use `.padding(.horizontal, DesignSystem.Metrics.cornerButtonInset)` on the button *row* (an `HStack`
that already pins its button to one side with a `Spacer`). Because the button is pinned and the
`Spacer` absorbs the opposite side, horizontal padding moves the button toward center by exactly the
inset — x-axis only, no height change, nothing else on screen affected.

- **`WatchActiveSessionView.swift`** — the bottom-row `HStack { ShareButton; Spacer(); LogBadgeButton }`
  (inside the `ZStack` that also holds the centered Stop octagon): add
  `.padding(.horizontal, DesignSystem.Metrics.cornerButtonInset)` to that **HStack**. The centered Stop
  button is a sibling in the `ZStack`, not in the HStack, so it stays put.
- **`WatchLogView.swift`** — the `HStack { Spacer(); BackButton(...) }`: add the same
  `.padding(.horizontal, ...)` (keep the existing `.padding(.top, 4)`).
- **`WatchShareView.swift`** — the `HStack { BackButton(...); Spacer() }`: add the same
  `.padding(.horizontal, ...)` (keep the existing `.padding(.top, 4)`).
- **First-Launch screen** — its bottom row is centered "SLIDE TO BEGIN" text, no corner buttons; do nothing.

(There is no `bezelInsets` / GeometryReader / coordinate-space machinery in this approach — it's a
single computed constant per model.)

## Step 3 — Build
- **Project**: `Graces Holy Bell.xcodeproj` · **Scheme**: `Graces Holy Bell Watch App Watch App`
- Build should complete with no warnings/errors. (Single-file SourceKit "Cannot find type…" diagnostics
  are expected noise in this multi-file watch target — trust the full `xcodebuild` result.)

## Step 4 — Iterative in-sim tuning (the important part)
The absolute magnitude is set by eye. Loop until it looks right:

1. **Build & run on three sims**: 40mm SE 3, 46mm Series 11, 49mm Ultra 3.
2. **Confirm the invariant**: SE 40mm corner buttons are unchanged (inset must be exactly 0 there).
3. **Assess the two rounded models** (Series 11 46mm and Ultra 3 49mm) on the **Active, Log, and
   Share** screens. For each lower-left / lower-right button ask:
   - Is the button fully clear of the curved corner (not clipped)?
   - Is it pulled in *just* enough — not so far that it looks floated toward the middle?
4. **Adjust `DesignSystem.Metrics.cornerInsetScale`** and rebuild:
   - Buttons still clipped → increase the scale.
   - Buttons pulled too far in → decrease it.
   - Because a single linear scale drives every model, tuning against the Series 11 and Ultra (the two
     extremes the app runs on) locks in the whole range.
5. **Repeat 1–4** until both models look right at the same scale value.
6. **Record the final `cornerInsetScale`** in the constant.

### Fallback if the linear model doesn't hold
If a single `cornerInsetScale` can make the Series 11 look right *or* the Ultra look right but not both
at once, the relationship isn't linear-from-28. In that case switch `cornerButtonInset` to an explicit
per-radius lookup (small `switch` returning a hand-tuned pt value per radius: 34, 38, 41, 45, 49, 54, 56),
tuned the same iterative way. Keep radius 28 → 0.

## Do not regress (already-approved changes to preserve)
- **`PixelGridButton.swift`**: `BackButton` tap-area enlargement (`.padding(8).contentShape(Rectangle()).padding(-8)`).
- **`WatchLogView.swift`**: title via `WatchSessionHeader`; version label (`AppVersion.label`, `pixelFont(8)`)
  moved below the log box inside the `ScrollView`; BACK button `size: 21`, right-aligned; `.padding(.top, 4)`.
- **`WatchPrayerLogView.swift`**: version label removed from inside the bordered log box.
- **`WatchShareView.swift`**: "JOIN US IN PRAYER" blink via `TimelineView(.periodic(by: 0.5))`; card `VStack(spacing: 7)`.
