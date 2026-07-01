import SwiftUI

/// Log screen — shown during an active session when the user taps LOG.
/// Timer keeps ticking; only the log scrolls (via digital crown).
struct WatchLogView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        // Single per-second clock for the timer and the log's live last row.
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            screen(now: context.date)
        }
        // Analytics (additive): the discrete Watch log screen was opened.
        .onAppear { viewModel.recordLogViewed() }
    }

    private func screen(now: Date) -> some View {
        VStack(spacing: 0) {
            // Shared header component — guarantees the title, timer, and
            // "SINCE LAST PRAYER" text land at the exact same spot as Active.
            // Needs the same 14pt total horizontal inset as WatchScreenLayout
            // (this screen's own padding below is only 8), or the narrower
            // wrap width on Active makes minimumScaleFactor shrink it more,
            // so the title renders at a visibly different size between screens.
            WatchSessionHeader(viewModel: viewModel, now: now)
                .padding(.horizontal, 6)
                .padding(.bottom, 3)

            // Scrollable log + version marker — fills remaining space. The
            // version label lives outside the log box, below it, so it
            // scrolls into view with the rest of the content on small watches.
            ScrollView {
                VStack(spacing: 3) {
                    WatchPrayerLogView(viewModel: viewModel, now: now)

                    Text(AppVersion.label)
                        .font(.pixelFont(8))
                        .foregroundStyle(Color.lcdMid)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxHeight: .infinity)
            .focusable()

            // BACK button — right-aligned to match the log button's position
            // on the Active screen. Sized to match the stop button's 21pt
            // height, with an enlarged, layout-neutral tap target so
            // mis-taps are less likely.
            HStack {
                Spacer()
                BackButton(action: { viewModel.showingLog = false }, size: 21)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        // Same full-screen treatment as WatchScreenLayout: clear the system
        // clock at the top, small margin above the rounded bottom edge.
        .padding(.top, DesignSystem.Metrics.clockClearance)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
