import SwiftUI

/// Idle (cleared) screen — shown after STOP when entries exist.
/// Only the log scrolls; the rest of the layout is fixed.
struct WatchIdleClearedView: View {

    let viewModel: WatchSessionViewModel
    @State private var showClearConfirmation = false

    private var endedText: String {
        if let stoppedAt = viewModel.sessionStoppedAt {
            return "ENDED \(TimeFormatter.wallClockString(from: stoppedAt))"
        }
        return "SESSION ENDED"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("GRACE'S\nHOLY BELL")
                .font(.pixelFont(11))
                .foregroundStyle(Color.lcdDark)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            // Ended timestamp
            Text(endedText)
                .font(.pixelFont(7))
                .foregroundStyle(Color.lcdMid)
                .padding(.top, 4)

            // Scrollable log — fills remaining space
            ScrollView {
                WatchPrayerLogView(viewModel: viewModel)
            }
            .frame(maxHeight: .infinity)
            .focusable()
            .padding(.top, 6)

            // CLEAR (X) button
            ClearButton {
                showClearConfirmation = true
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Clear the prayer log?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) { viewModel.sendClearLog() }
            Button("No", role: .cancel) {}
        }
    }
}
