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
            // This screen's own horizontal margin (14, below) now matches
            // WatchScreenLayout's, so no extra inset is needed here.
            WatchSessionHeader(viewModel: viewModel, now: now)
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
            .clipped()
            .focusable()

            // BACK button — right-aligned to match the log button's position
            // on the Active screen. Sized to match the stop button's 21pt
            // height, with an enlarged, layout-neutral tap target so
            // mis-taps are less likely.
            HStack {
                Spacer()
                BackButton(action: { viewModel.showingLog = false }, size: 21)
            }
            .padding(.horizontal, DesignSystem.Metrics.cornerButtonInset)
            .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        // Same full-screen treatment as WatchScreenLayout: clear the system
        // clock at the top, small margin above the rounded bottom edge.
        .padding(.top, DesignSystem.Metrics.clockClearance)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
