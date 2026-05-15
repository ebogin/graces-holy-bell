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
                .padding(.top, 10)

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
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
