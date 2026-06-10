import SwiftUI
import SwiftData

/// ACTIVE SESSION screen — a prayer session is in progress.
///
/// LCD green background, pixel-font timer, animated praying figure,
/// growing log box, PRAY slider, and octagon STOP button.
struct ActiveSessionView: View {

    let viewModel: SessionViewModel
    let amenAlarmSettings: AmenAlarmSettings
    @State private var showStopConfirmation = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // LCD gradient background — fills behind safe areas
            LinearGradient(
                colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Tap-outside-to-dismiss overlay — only active when settings is open
            if showSettings {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { dismissSettings() }
            }

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

                    // Content area — settings panel OR prayer log, same space
                    ZStack(alignment: .topLeading) {

                        // Prayer log with label (hidden behind settings when open)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PRAYER LOG")
                                .font(.pixelFont(7))
                                .foregroundStyle(Color.lcdMid)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            PrayerLogView(viewModel: viewModel)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(showSettings ? 0 : 1)

                        // Settings panel (slides in from left)
                        if showSettings {
                            SettingsView(settings: amenAlarmSettings)
                                .transition(.move(edge: .leading))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Prevent taps inside the content area from bubbling to dismiss overlay
                    .contentShape(Rectangle())
                    .onTapGesture { /* absorb taps inside the panel */ }

                    // PRAY slider
                    PraySlider(label: "PRAY") {
                        viewModel.logPrayer()
                    }
                    .frame(maxWidth: .infinity)

                    // Bottom buttons: Gear/X toggle | Stop | placeholder (balance)
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSettings.toggle()
                            }
                        } label: {
                            Image(systemName: showSettings ? "xmark" : "gearshape.fill")
                                .accessibilityIdentifier("settings-button")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.lcdDark)
                                .frame(width: 37, height: 36)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)

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
                        .accessibilityIdentifier("stop-button")

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

    private func dismissSettings() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showSettings = false
        }
    }
}

#Preview("Active session") {
    let container = try! ModelContainer(for: PrayerSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ActiveSessionView(
        viewModel: SessionViewModel(modelContext: container.mainContext),
        amenAlarmSettings: AmenAlarmSettings()
    )
}
