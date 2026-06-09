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
            // LCD gradient background — fills behind safe areas
            LinearGradient(
                colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Core Content Stack (Figma gap: 20px → 7pt) ───────────
                VStack(spacing: 7) {
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(17))
                        .foregroundStyle(Color.lcdTitle)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    LiveTimerView(viewModel: viewModel)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // ── Animated praying figure ──────────────────────────────
                PrayingFigureView(pose: .praying, scale: 2.6)

                Spacer(minLength: 12)

                // ── Bottom Content Stack (Figma gap: 50px → 17pt) ────────
                VStack(spacing: 17) {

                    // Prayer log with label
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PRAYER LOG")
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        PrayerLogView(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity)

                    // PRAY slider
                    PraySlider(label: "PRAY") {
                        viewModel.logPrayer()
                    }
                    .frame(maxWidth: .infinity)

                    // Bottom buttons: Gear | Stop | placeholder (balance)
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.lcdDark)
                            .frame(width: 37, height: 36)

                        Spacer()

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

                        Spacer()

                        Color.clear
                            .frame(width: 37, height: 36)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .confirmationDialog(
            "End Praying?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Log", role: .destructive) {
                viewModel.clearLog()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clear the log and start fresh. This CANNOT BE UNDONE")
        }
    }
}

#Preview("Active session") {
    let container = try! ModelContainer(for: PrayerSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ActiveSessionView(viewModel: SessionViewModel(modelContext: container.mainContext))
}
