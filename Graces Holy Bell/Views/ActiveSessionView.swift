import SwiftUI

/// The ACTIVE SESSION screen — a prayer session is in progress.
///
/// Shows the live elapsed timer, growing prayer log, PRAY slider to log prayers,
/// and a STOP button (with confirmation) to end the session.
struct ActiveSessionView: View {

    let viewModel: SessionViewModel
    @State private var showStopConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Grace's Holy Bell")
                .font(.title)
                .fontWeight(.semibold)

            // Large live elapsed timer
            LiveTimerView(viewModel: viewModel)
                .padding(.vertical, 8)

            // Prayer log (grows with each prayer)
            PrayerLogView(viewModel: viewModel)

            // PRAY slider (logs prayer + restarts timer)
            PraySlider {
                viewModel.logPrayer()
            }

            // STOP button
            Button("Stop Session", role: .destructive) {
                showStopConfirmation = true
            }
            .padding(.bottom)
        }
        .padding()
        .confirmationDialog(
            "End prayer session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                viewModel.stopSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The clock will stop and no final prayer will be recorded.")
        }
    }
}
