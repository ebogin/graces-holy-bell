import SwiftUI
import SwiftData

/// IDLE state screen — no active prayer session.
/// All element positions come from PrayerScreenLayout, shared with
/// ActiveSessionView, so the figure/slider/buttons never move between screens.
struct IdleView: View {

    let viewModel: SessionViewModel
    let amenAlarmSettings: AmenAlarmSettings
    let consent: AnalyticsConsent
    var isWatchAvailable: Bool = false
    var onForceSync: () -> Void = {}
    @State private var showSettings = false
    @State private var showShareWithFriend = false

    var body: some View {
        PrayerScreenLayout(
            figurePose: .idle,
            onBackgroundTap: showSettings ? { dismissSettings() } : nil
        ) {

            // Header: big two-line app title
            Text("GRACE'S\nHOLY BELL")
                .font(.pixelFont(28, relativeTo: .largeTitle))
                .foregroundStyle(Color.lcdDark)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

        } middle: {

            // Settings panel OR welcome text, same space
            ZStack(alignment: .topLeading) {

                // Welcome text (visible when settings hidden)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("Welcome to your favorite app to time prayer duration.")
                        .font(.pixelFont(12, relativeTo: .body))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(3)

                    Spacer().frame(height: 67)

                    // Square-wave blink driven by the timeline clock — unlike a
                    // repeating Timer, this pauses automatically off-screen.
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Text("SLIDE TO BEGIN")
                            .font(.pixelFont(12, relativeTo: .body))
                            .foregroundStyle(Color.lcdMid)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(showSettings ? 0 : 1)

                // Settings panel (slides in from left)
                if showSettings {
                    SettingsView(
                        settings: amenAlarmSettings,
                        consent: consent,
                        isWatchAvailable: isWatchAvailable,
                        onForceSync: onForceSync,
                        analytics: viewModel.analytics
                    )
                    .transition(.move(edge: .leading))
                }
            }

        } slider: {

            // Idle always means "no session" — ending a session clears its log,
            // so there is never an old log to confirm over.
            PraySlider(label: "PRAY") {
                viewModel.startNewSession()
            }

        } buttons: {

            // Share | Stop (inert) | Gear/X toggle
            HStack {
                Button {
                    showShareWithFriend = true
                } label: {
                    ShareIconShape()
                        .fill(Color.lcdDark)
                        .frame(width: BottomIconMetrics.shareWidth, height: BottomIconMetrics.shareHeight)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share-with-friend-button")

                Spacer()

                ZStack {
                    // Muted fill — the idle stop button is inert (timer not running),
                    // so it reads as disabled while staying in the LCD-green palette.
                    Octagon()
                        .fill(Color.lcdMid)
                        .frame(width: BottomIconMetrics.width, height: BottomIconMetrics.height)
                    Rectangle()
                        .fill(Color.lcdThumbText)
                        .frame(width: 12, height: 12)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: showSettings ? "xmark" : "gearshape.fill")
                        .accessibilityIdentifier("settings-button")
                        .font(.title)
                        .foregroundStyle(Color.lcdDark)
                        .frame(width: BottomIconMetrics.width, height: BottomIconMetrics.height)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showShareWithFriend) {
            ShareWithFriendView()
        }
    }

    private func dismissSettings() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showSettings = false
        }
    }
}

#Preview("Idle — no log") {
    let container = try! ModelContainer(for: PrayerSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    IdleView(
        viewModel: SessionViewModel(modelContext: container.mainContext),
        amenAlarmSettings: AmenAlarmSettings(),
        consent: AnalyticsConsent()
    )
}
