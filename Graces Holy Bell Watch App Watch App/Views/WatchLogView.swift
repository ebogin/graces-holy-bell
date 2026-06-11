import SwiftUI

/// Log screen — shown during an active session when the user taps LOG.
/// Timer keeps ticking; only the log scrolls (via digital crown).
struct WatchLogView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        VStack(spacing: 3) {
            // Header — same as Active screen
            Text("GRACE'S HOLY BELL")
                .font(.pixelFont(8.5))
                .foregroundStyle(Color.lcdMid)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Live timer (keeps ticking while viewing log)
            WatchLiveTimerView(viewModel: viewModel)

            // Scrollable log — fills remaining space
            ScrollView {
                WatchPrayerLogView(viewModel: viewModel)
            }
            .frame(maxHeight: .infinity)
            .focusable()

            // BACK button
            BackButton {
                viewModel.showingLog = false
            }
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
