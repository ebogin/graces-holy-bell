import SwiftUI
import SwiftData

/// IDLE state screen — no active prayer session.
///
/// Layout mirrors ActiveSessionView's Core Content Stack structure exactly:
/// invisible row 1 (small title placeholder) + visible row 2 (big app title) +
/// invisible row 3 (subtitle placeholder). This keeps the praying figure and
/// bottom stack at identical vertical positions across both screens.
struct IdleView: View {

    let viewModel: SessionViewModel
    @State private var showNewSessionConfirmation = false
    @State private var blinkVisible = true

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

                    // Row 1: invisible — mirrors active screen's small title (17pt)
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(17))
                        .opacity(0)
                        .frame(maxWidth: .infinity)

                    // Row 2: main app title — 84px → 28pt, lcdDark, two lines
                    Text("GRACE'S\nHOLY BELL")
                        .font(.pixelFont(28))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)

                    // Row 3: invisible — mirrors active screen's "SINCE LAST PRAYER" (7pt)
                    Text("SINCE LAST PRAYER")
                        .font(.pixelFont(7))
                        .opacity(0)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // ── Animated praying figure (idle pose) ──────────────────
                PrayingFigureView(pose: .idle, scale: 2.6)

                Spacer(minLength: 12)

                // ── Bottom Content Stack (Figma gap: 62px → 21pt) ────────
                VStack(spacing: 21) {

                    // Content area — welcome text and "SLIDE TO BEGIN",
                    // justify-end with 200px → 67pt gap between them
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text("Welcome to your favorite app to time prayer duration.")
                            .font(.pixelFont(12))
                            .foregroundStyle(Color.lcdDark)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(3)

                        Spacer().frame(height: 67)

                        Text("SLIDE TO BEGIN")
                            .font(.pixelFont(12))
                            .foregroundStyle(Color.lcdMid)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .opacity(blinkVisible ? 1 : 0)
                            .onAppear {
                                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                                    blinkVisible.toggle()
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)

                    // PRAY slider — same component as active screen
                    PraySlider(label: "PRAY") {
                        if viewModel.hasExistingLog {
                            showNewSessionConfirmation = true
                        } else {
                            viewModel.startNewSession()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Bottom buttons: Gear (inert) | Stop (inert) | Placeholder
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.lcdDark)
                            .frame(width: 37, height: 36)

                        Spacer()

                        // Disabled stop button — muted green since the timer isn't running
                        ZStack {
                            Octagon()
                                .fill(Color.lcdMid)
                                .frame(width: 56, height: 56)
                            Rectangle()
                                .fill(Color.lcdThumbText)
                                .frame(width: 18, height: 18)
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
