# Feature: Watch QR Share ("Join Us in Prayer")

Status: planned · Target: `Graces Holy Bell Watch App Watch App` (watchOS) · Author handoff doc

## 1. What we're building

Bring the iPhone's "Share with a Friend" QR feature to the Apple Watch so a user
can let someone scan a QR code straight off their wrist to join the Grace's Holy
Bell waiting list.

Two screens, both designed in Figma (file `aFFwA2eZWpjhJJVvQIh0Sb`):

1. **Active Prayer screen** (Figma node `293-23`) — the existing active-session
   screen, plus a new **share icon** in the lower-left of the bottom row (to the
   left of the centered STOP octagon; the log badge stays trailing). The icon is
   the lightweight share/export glyph (rounded tray + arrow leaving the top-right,
   Figma node `296-524`), implemented as a vector `Shape` in `ShareButton.swift`.
2. **"Join Us in Prayer" screen** (Figma node `296-531`) — opened by tapping the
   share icon. Header is a single **"Share the app"** line (the title/timer/
   "SINCE LAST PRAYER" block is NOT shown here), then a `JOIN US IN PRAYER`
   prompt + the QR code in a bordered LCD card (QR background = card colour
   `#c0d0a8`), and a **back button** (dark circle + light chevron) lower-left
   that returns to the active screen.

The QR encodes the same kind of link the phone's QR does: the public waitlist
form carrying an anonymous referral code.

## 2. Locked product decisions

- **Entry point:** Active-prayer screen ONLY. The share arrow does not appear on
  the idle / first-launch screen. (Matches the provided Figma; no idle-screen
  design exists.)
- **Referral code source:** the watch **mints and stores its own anonymous
  referral code** in its own `UserDefaults` (Option B). Rationale: the watch is
  frequently used away from the phone, and this path is instant, fully offline,
  standalone, and needs no WatchConnectivity wire-format change. The QR is
  generated on-device with CoreImage in a few milliseconds — there is never a
  "waiting for the phone" or blank-screen state.
  - Consequence: a watch and its paired phone hold two distinct anonymous codes
    for the same human. This is consistent with the app's existing model (codes
    are anonymous and per-install) and is acceptable for in-person QR growth,
    where what matters is that the scan converts.
  - **Surface marking (optional, see Stage 4):** add a `src` query param
    (`phone` | `watch`) to the share URL so analytics can attribute a scan to the
    surface that produced it, without changing the opaque `ref` code itself.

## 3. How the phone feature works today (reference)

- `Graces Holy Bell/Utilities/WaitlistLink.swift` — mints an 8-char anonymous
  code once, stores it in `UserDefaults` under `"waitlistReferralCode"`, and
  builds `https://boginfactory.com/grace-waitlist.html?ref=<code>`.
- `Graces Holy Bell/Utilities/QRCodeGenerator.swift` — `QRCodeGenerator.image(from:dark:light:)`
  renders a QR via `CIFilter.qrCodeGenerator()`, recolors it to the LCD palette,
  upscales 16× nearest-neighbour, returns a `UIImage`. Display with
  `.interpolation(.none)`. (CoreImage + UIImage are available on watchOS, so this
  compiles for the watch target unchanged.)
- `Graces Holy Bell/Views/ShareWithFriendView.swift` — the phone's share sheet
  (header + blurb + QR card + ShareLink + privacy note). The watch screen is
  QR-only: no blurb, no ShareLink button.
- Landing page `docs/grace-waitlist.html` reads `?ref=` (line ~268) and submits
  it as `referrer`. It does not currently read `src`.

## 4. Watch architecture (relevant files)

- `Graces Holy Bell Watch App Watch App/ViewModels/WatchSessionViewModel.swift`
  — `WatchRoute { firstLaunch, active, log }`; a local `showingLog` flag drives
  the active→log swap. `route` returns `.log` when `showingLog` and active.
- `.../ContentView.swift` — `NavigationStack` + `switch viewModel.route` renders
  the full-screen view for each route with an opacity transition.
- `.../Views/WatchActiveSessionView.swift` — bottom row is a `ZStack`: STOP
  octagon centered, `LogBadgeButton` trailing.
- `.../Views/WatchLogView.swift` — the model to copy for the new screen: same
  header, content, then a `BackButton { viewModel.showingLog = false }` at the
  bottom; uses `DesignSystem.Metrics.clockClearance` top padding.
- `.../Views/WatchScreenLayout.swift` — shared scaffold for start/active; sizes
  the bottom-row slot from a hidden template (verify the share arrow fits the
  existing reserved height; it's the same ~24–28px scale as the other buttons).
- `.../Views/Components/PixelGridButton.swift` — `PixelGridButton` (13×13 grid
  renderer) and `BackButton` (dark circle + light chevron). The new share arrow
  is a `PixelGridButton` with a forward-arrow grid.
- `.../Theme.swift` & `.../DesignSystem.swift` — LCD palette + pixel font. The
  watch has its own copies of the color tokens (`Color.lcdDark`, etc.).

### Code sharing
- `WaitlistLink.swift` → moved to `Shared/` (Foundation-only, compiles on both
  targets). Because each device reads its own `UserDefaults`, it automatically
  yields a separate code per device — which IS Option B. iPhone unchanged.
- `QRCodeGenerator.swift` (CoreImage) **stays iPhone-only** in
  `Graces Holy Bell/Utilities/`.

### ⚠️ watchOS QR constraint (discovered during build)
**CoreImage.framework does not exist in the watchOS SDK** — `CIFilter.qrCodeGenerator()`
cannot run on the watch, and there is no native QR-generation API on watchOS.
So the watch needs its own encoder. Decision (approved): vendor the MIT-licensed
pure-Swift QR encoder `fwcd/swift-qrcode-generator` (a port of Nayuki's reference
library) into `Shared/QRCodeKit/` and render the module matrix with a SwiftUI
`Canvas`. Audited: only `import Foundation`, no network/file/process/env access.
- API: `try QRCode.encode(text:ecl:)` → `qr.size` (Int) + `qr.getModule(x:y:)` (Bool).
- Use `ecl: .medium` to match the phone's correction level ("M").
- Compiles on BOTH iOS and watchOS SDKs (verified). Could later replace the
  phone's CoreImage path to unify, but out of scope for now.

## 5. Planned changes (summary; see staged plan in the conversation)

1. ✅ DONE — `WaitlistLink` → `Shared/`; vendor `Shared/QRCodeKit/`; both
   iOS and watchOS schemes build clean.
2. Add `ShareArrowButton` (pixel grid) and wire it into the active screen's
   bottom row (lower-left); add `showingShare` state + `.share` route.
3. Build `WatchShareView` ("JOIN US IN PRAYER?" + QR card via vendored encoder +
   back button), mirroring `WatchLogView`. Add a `WatchQRCodeView` Canvas renderer.
4. ✅ DONE — `src` surface param end-to-end: `WaitlistLink.shareURL(source:)`
   (watch=`watch`, phone defaults to `phone`), landing page reads/sends `src`,
   Worker validates + persists `source`, schema + migration note + CSV/email +
   tests updated. ⚠️ Requires a live D1 migration before the new Worker deploy
   (see "Deploy steps" below).

## Deploy steps (NOT yet done — outward-facing, needs user)
Ordering matters or live signups break:
1. Migrate live D1 FIRST:
   `npx wrangler d1 execute grace-waitlist --remote --command "ALTER TABLE signups ADD COLUMN source TEXT"`
2. Deploy the Worker (`waitlist/`).
3. Mirror `docs/grace-waitlist.html` to `ebogin/Boginfactory-Landing-Page`
   (per project rule). Safe before steps 1–2 too: the old Worker ignores the
   extra `src` field.

## 6. Out of scope

- Idle/first-launch share entry point.
- Syncing the phone's referral code to the watch (Option A).
- A watch ShareLink / "share via apps" button (QR-only on the watch).
- Any change to the QR's anonymity model or privacy posture.
