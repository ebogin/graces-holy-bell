import SwiftUI

/// Watch ACTIVE SESSION screen — a prayer session is in progress.
///
/// Shows the live elapsed timer, countdown to next suggested prayer,
/// prayer log (scrollable via Digital Crown),
/// PRAY slider to log prayers, and STOP button with confirmation.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    @State private var showStopConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Large live timer
                WatchLiveTimerView(viewModel: viewModel)
                    .padding(.vertical, 4)

                // Countdown to next suggested prayer
                WatchCountdownView(viewModel: viewModel)
                    .padding(.bottom, 2)

                Divider()

                // Prayer log
                WatchPrayerLogView(viewModel: viewModel)

                // PRAY slider
                WatchPraySlider {
                    viewModel.sendPray()
                }
                .padding(.top, 4)

                // STOP button
                Button("Stop Session", role: .destructive) {
                    showStopConfirmation = true
                }
                .font(.caption)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Holy Bell")
        .confirmationDialog(
            "End session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                viewModel.sendStop()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No final prayer will be recorded.")
        }
    }
}
