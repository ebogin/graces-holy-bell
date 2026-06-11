import SwiftUI
import WatchKit

/// Shared scaffold for the Watch start and active screens.
///
/// Owns the position of every persistent element — header block, praying
/// figure, PRAY slider, and bottom row — so they render at identical spots
/// on both screens and the start→active switch reads as "the figure started
/// animating" rather than a screen change.
///
/// The header and bottom-row slots are sized by hidden copies of the tallest
/// content either screen puts there. Because the templates use the same fonts
/// as the real content, the reserved space tracks Dynamic Type automatically.
struct WatchScreenLayout<Header: View, Slider: View, BottomRow: View>: View {

    let figurePose: WatchPrayingFigureView.Pose
    @ViewBuilder var header: Header
    @ViewBuilder var slider: Slider
    @ViewBuilder var bottomRow: BottomRow

    /// Largest the figure is allowed to render; smaller watches get whatever
    /// height remains between the fixed header and bottom container.
    private let maxFigureHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {

            // ── Header area ───────────────────────────────────────────────
            ZStack {
                headerSizingTemplate.hidden()
                header
            }
            .frame(maxWidth: .infinity)

            // ── Figure — scales to the leftover space, centered ───────────
            GeometryReader { geo in
                WatchPrayingFigureView(
                    pose: figurePose,
                    height: min(maxFigureHeight, max(geo.size.height - 4, 0))
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }

            // ── Bottom container: slider + button/label row ──────────────
            VStack(spacing: 0) {
                slider
                    .padding(.vertical, 2)

                ZStack {
                    bottomRowSizingTemplate.hidden()
                    bottomRow
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        // The nav bar is hidden and safe areas are ignored, so the screen's
        // full height is ours: reserve only the system clock band at the top
        // and a small margin above the rounded bottom edge. Everything
        // reclaimed goes to the flexible figure slot.
        .padding(.top, DesignSystem.Metrics.clockClearance)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
        .ignoresSafeArea()
    }

    /// Invisible copy of the active screen's header (small title + timer +
    /// caption) — the tallest header either screen renders.
    private var headerSizingTemplate: some View {
        VStack(spacing: 2) {
            Text("GRACE'S HOLY BELL")
                .font(.pixelFont(8))
                .lineLimit(1)
            VStack(spacing: 3) {
                Text("00:00:00")
                    .font(.pixelFont(WatchLiveTimerView.timerFontSize, relativeTo: .title2))
                    .lineLimit(1)
                Text("SINCE LAST PRAYER")
                    .font(.pixelFont(7, relativeTo: .caption2))
            }
        }
    }

    /// Invisible copies of both screens' bottom rows, overlaid so the slot is
    /// sized to the tallest: stop button + log badge (active) and the blinking
    /// "SLIDE TO BEGIN" hint (start).
    private var bottomRowSizingTemplate: some View {
        ZStack {
            Octagon()
                .frame(width: 24, height: 24)
            LogBadgeButton(count: 0) { }
            Text("SLIDE TO BEGIN")
                .font(.pixelFont(7, relativeTo: .caption2))
        }
    }
}
