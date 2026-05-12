import SwiftUI
import SwiftData

/// IDLE state screen — no active prayer session.
///
/// LCD green background with pixel-art typography.
/// Shows the previous session log in a bordered box and
/// a START PRAYER slider at the bottom.
struct IdleView: View {

    let viewModel: SessionViewModel
    @State private var showNewSessionConfirmation = false

    var body: some View {
        ZStack {
            // LCD gradient background
            LinearGradient(
                colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 10) {
                    Text("Grace's Holy Bell")
                        .font(.pixelFont(12))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.center)

                    Text("NO ACTIVE SESSION")
                        .font(.pixelFont(8))
                        .foregroundStyle(Color.lcdMid)
                }
                .padding(.top, 28)
                .padding(.horizontal)

                // ── Praying figure ───────────────────────────────────────
                PrayingFigureView(pose: .idle, scale: 2.6)
                    .padding(.top, 20)

                // ── Decorative divider ───────────────────────────────────
                Rectangle()
                    .fill(Color.lcdDark.opacity(0.25))
                    .frame(height: 3)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)

                // ── Previous log (if any) ────────────────────────────────
                if viewModel.hasExistingLog {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREVIOUS PRAYER LOG")
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid)
                            .padding(.horizontal)

                        PrayerLogView(viewModel: viewModel)
                            .padding(.horizontal)
                    }
                } else {
                    Spacer()
                }

                Spacer(minLength: 16)

                // ── START PRAYER slider ──────────────────────────────────
                PraySlider(label: "START PRAYER") {
                    if viewModel.hasExistingLog {
                        showNewSessionConfirmation = true
                    } else {
                        viewModel.startNewSession()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
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

#Preview("Idle — no log") {
    let container = try! ModelContainer(for: PrayerSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    IdleView(viewModel: SessionViewModel(modelContext: container.mainContext))
}
