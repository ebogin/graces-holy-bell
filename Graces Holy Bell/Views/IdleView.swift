import SwiftUI

/// The IDLE state screen — no active prayer session.
///
/// Shows the previous session's log (if any) and the PRAY slider to start a new session.
/// If a previous log exists, sliding PRAY shows a confirmation dialog before clearing it.
struct IdleView: View {

    let viewModel: SessionViewModel
    @State private var showNewSessionConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Grace's Holy Bell")
                .font(.title)
                .fontWeight(.semibold)

            Text("No active session")
                .foregroundStyle(.secondary)

            // Previous session log (read-only)
            if viewModel.hasExistingLog {
                PrayerLogView(viewModel: viewModel)
            } else {
                Spacer()
            }

            // PRAY slider
            PraySlider {
                if viewModel.hasExistingLog {
                    showNewSessionConfirmation = true
                } else {
                    viewModel.startNewSession()
                }
            }
            .padding(.bottom)
        }
        .padding()
        .confirmationDialog(
            "Start new session?",
            isPresented: $showNewSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start New Session", role: .destructive) {
                viewModel.startNewSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your previous prayer log will be cleared.")
        }
    }
}
