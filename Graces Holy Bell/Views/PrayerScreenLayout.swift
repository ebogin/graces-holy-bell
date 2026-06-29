import SwiftUI

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
    /// Shows the transient "SYNCING…" badge at the top while a reconcile is pending.
    var isSyncing: Bool = false
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
        // Transient reconcile badge, floating at the very top so it never shifts
        // the carefully-tuned layout below it.
        .overlay(alignment: .top) {
            if isSyncing {
                SyncingBadge()
                    .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSyncing)
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
