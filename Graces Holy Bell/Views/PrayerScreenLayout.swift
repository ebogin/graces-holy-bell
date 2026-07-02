import SwiftUI

/// Shared frame size for the bottom row's three icon buttons (Share, Stop,
/// Gear/X) on both IdleView and ActiveSessionView, so they read as a matched
/// set regardless of each icon's native aspect ratio.
enum BottomIconMetrics {
    static let width: CGFloat = 37
    static let height: CGFloat = 36

    // The Share icon's vector art fills its frame edge-to-edge (unlike the
    // SF Symbol glyphs, which have built-in visual padding), so it reads as
    // oversized at the shared size — trimmed down to match.
    static let shareWidth: CGFloat = width - 10
    static let shareHeight: CGFloat = height - 10
}

/// Shared scaffold for the iPhone idle and active screens.
///
/// Owns the position of every persistent element — header area, praying
/// figure, middle content, PRAY slider, and bottom button row — so both
/// screens render them at identical spots and the idle→active switch reads
/// as the figure simply starting to animate.
///
/// The header slot is sized by hidden copies of BOTH screens' headers, so it
/// reserves the tallest one on either screen. Because the templates use the
/// same fonts as the real content, the reserved space tracks Dynamic Type
/// automatically.
struct PrayerScreenLayout<Header: View, Middle: View, Slider: View, Buttons: View>: View {

    let figurePose: PrayingFigureView.Pose
    /// Tap-anywhere-to-dismiss handler; pass non-nil while the settings panel is open.
    var onBackgroundTap: (() -> Void)? = nil
    @ViewBuilder var header: Header
    @ViewBuilder var middle: Middle
    @ViewBuilder var slider: Slider
    @ViewBuilder var buttons: Buttons

    var body: some View {
        ZStack {
            // LCD gradient background — fills behind safe areas
            LinearGradient(
                colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Tap-outside-to-dismiss overlay — only active when settings is open
            if let onBackgroundTap {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: onBackgroundTap)
            }

            VStack(spacing: 0) {

                // ── Header area — sized to the tallest header variant ─────
                ZStack {
                    activeHeaderTemplate.hidden()
                    idleHeaderTemplate.hidden()
                    header
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // ── Animated praying figure ───────────────────────────────
                PrayingFigureView(pose: figurePose, scale: 2.6)

                Spacer(minLength: 12)

                // ── Bottom stack: flexible content, slider, buttons ───────
                VStack(spacing: 18) {
                    middle
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Absorb taps so they don't reach the dismiss overlay
                        .contentShape(Rectangle())
                        .onTapGesture { }

                    slider
                        .frame(maxWidth: .infinity)

                    buttons
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    /// Invisible copy of the active screen's header: small title + timer + caption.
    private var activeHeaderTemplate: some View {
        VStack(spacing: 7) {
            Text("GRACE'S HOLY BELL")
                .font(.pixelFont(17, relativeTo: .title3))
                .lineLimit(1)
            VStack(spacing: 6) {
                Text("00:00:00")
                    .font(.pixelFont(28, relativeTo: .largeTitle))
                    .lineLimit(1)
                Text("SINCE LAST PRAYER")
                    .font(.pixelFont(7, relativeTo: .caption2))
            }
        }
    }

    /// Invisible copy of the idle screen's header: big two-line app title.
    private var idleHeaderTemplate: some View {
        Text("GRACE'S\nHOLY BELL")
            .font(.pixelFont(28, relativeTo: .largeTitle))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
