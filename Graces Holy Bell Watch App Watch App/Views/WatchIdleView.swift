import SwiftUI

/// Watch IDLE state screen — no active prayer session.
///
/// Shows the previous session's log (scrollable via Digital Crown) and the PRAY slider.
/// If a previous log exists, the slider triggers a confirmation before starting a new session.
struct WatchIdleView: View {

    let viewModel: WatchSessionViewModel
    @State private var showNewSessionConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("No active session")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.hasExistingLog {
                    WatchPrayerLogView(viewModel: viewModel)
                }

                WatchPraySlider {
                    if viewModel.hasExistingLog {
                        showNewSessionConfirmation = true
                    } else {
                        viewModel.sendStart()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Holy Bell")
        .confirmationDialog(
            "Start new session?",
            isPresented: $showNewSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start New", role: .destructive) {
                viewModel.sendStart()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Previous log will be cleared.")
        }
    }
}
