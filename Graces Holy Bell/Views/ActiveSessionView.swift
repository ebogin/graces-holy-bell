import SwiftUI
import SwiftData

/// ACTIVE SESSION screen — a prayer session is in progress.
///
/// LCD green background, pixel-font timer, animated praying figure,
/// growing log box, PRAY slider, and octagon STOP button.
struct ActiveSessionView: View {

    let viewModel: SessionViewModel
    @State private var showStopConfirmation = false

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
                Text("Grace's Holy Bell")
                    .font(.pixelFont(12))
                    .foregroundStyle(Color.lcdDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                    .padding(.horizontal)

                // ── Live timer ───────────────────────────────────────────
                LiveTimerView(viewModel: viewModel)
                    .padding(.top, 16)

                // ── Animated praying figure ──────────────────────────────
                PrayingFigureView(pose: .praying, scale: 2.6)
                    .padding(.top, 14)

                // ── Prayer log ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRAYER LOG")
                        .font(.pixelFont(7))
                        .foregroundStyle(Color.lcdMid)
                        .padding(.horizontal)

                    PrayerLogView(viewModel: viewModel)
                        .padding(.horizontal)
                }
                .padding(.top, 14)

                Spacer(minLength: 16)

                // ── PRAY slider ──────────────────────────────────────────
                PraySlider(label: "PRAY") {
                    viewModel.logPrayer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Octagon STOP button ──────────────────────────────────
                Button {
                    showStopConfirmation = true
                } label: {
                    ZStack {
                        Octagon()
                            .fill(Color.lcdDark)
                            .frame(width: 56, height: 56)
                        Rectangle()
                            .fill(Color.lcdThumbText)
                            .frame(width: 18, height: 18)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
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
            Text("Clock stops. No final prayer recorded.")
        }
    }
}

#Preview("Active session") {
    let container = try! ModelContainer(for: PrayerSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ActiveSessionView(viewModel: SessionViewModel(modelContext: container.mainContext))
}
