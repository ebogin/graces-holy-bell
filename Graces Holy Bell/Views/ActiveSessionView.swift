import SwiftUI
import SwiftData

/// ACTIVE SESSION screen — a prayer session is in progress.
/// All element positions come from PrayerScreenLayout, shared with IdleView,
/// so the figure/slider/buttons never move between screens.
struct ActiveSessionView: View {

    let viewModel: SessionViewModel
    let amenAlarmSettings: AmenAlarmSettings
    let logExportSettings: LogExportSettings
    let consent: AnalyticsConsent
    var isWatchAvailable: Bool = false
    var onForceSync: () -> Void = {}
    /// Session ended with "Save Log to Notes" on — the parent (ContentView)
    /// presents the share sheet, because this view unmounts when the state
    /// flips to idle. Arguments: composed log text, prayer count.
    var onExportLog: (String, Int) -> Void = { _, _ in }
    @State private var showStopConfirmation = false
    @State private var showSettings = false
    @State private var showShareWithFriend = false
    /// Log row tapped — drives the edit/delete/intention detail sheet.
    @State private var selectedEntry: PrayerEntry?

    var body: some View {
        // Single per-second clock for the whole screen: the header timer, the
        // log's live last row, and the slider's alarm progress all derive from
        // one context.date instead of running their own TimelineViews.
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            #if DEBUG
            // Screenshot mode: render against a frozen clock when one is set.
            screen(now: ScreenshotClock.fixedNow ?? context.date)
            #else
            screen(now: context.date)
            #endif
        }
    }

    private func screen(now: Date) -> some View {
        PrayerScreenLayout(
            figurePose: .praying,
            onBackgroundTap: showSettings ? { dismissSettings() } : nil
        ) {

            // Header: small title over the live timer + "SINCE LAST PRAYER"
            VStack(spacing: 7) {
                Text("GRACE'S HOLY BELL")
                    .font(.pixelFont(17, relativeTo: .title3))
                    .foregroundStyle(Color.lcdTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

                LiveTimerView(viewModel: viewModel, now: now)
            }
            .frame(maxWidth: .infinity)

        } middle: {

            // Settings panel OR prayer log, same space
            ZStack(alignment: .topLeading) {

                // Prayer log with label (hidden behind settings when open)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PRAYER LOG")
                        .font(.pixelFont(7, relativeTo: .caption2))
                        .foregroundStyle(Color.lcdMid)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PrayerLogView(viewModel: viewModel, now: now) { entry in
                        selectedEntry = entry
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(showSettings ? 0 : 1)

                // Settings panel (slides in from left)
                if showSettings {
                    SettingsView(
                        settings: amenAlarmSettings,
                        logExport: logExportSettings,
                        consent: consent,
                        isWatchAvailable: isWatchAvailable,
                        onForceSync: onForceSync
                    )
                    .transition(.move(edge: .leading))
                }
            }

        } slider: {

            // Doubles as Amen Alarm progress bar when the alarm is on
            PraySlider(label: "PRAY", alarmProgress: alarmProgress(at: now)) {
                viewModel.logPrayer()
            }

        } buttons: {

            // Share | Stop | Gear/X toggle
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

                Button {
                    showStopConfirmation = true
                } label: {
                    ZStack {
                        Octagon()
                            .fill(Color.lcdDark)
                            .frame(width: BottomIconMetrics.width, height: BottomIconMetrics.height)
                        Rectangle()
                            .fill(Color.lcdThumbText)
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityIdentifier("stop-button")

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
        .confirmationDialog(
            "End Praying?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Log", role: .destructive) {
                endSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(logExportSettings.saveToNotesEnabled
                 ? "Clear the log and start fresh. This CANNOT BE UNDONE. Your log WILL be saved to Notes."
                 : "Clear the log and start fresh. This CANNOT BE UNDONE. Your log will NOT be saved to Notes.")
        }
        .sheet(isPresented: $showShareWithFriend) {
            ShareWithFriendView()
        }
        .sheet(item: $selectedEntry) { entry in
            PrayerDetailSheet(viewModel: viewModel, entry: entry)
        }
    }

    /// Ends the session: composes the Notes log first (clearing prunes the
    /// entries it reads), clears, then hands the text up for the share sheet.
    private func endSession() {
        let shouldExport = logExportSettings.saveToNotesEnabled && !viewModel.sortedEntries.isEmpty
        let logText = shouldExport ? viewModel.composeSessionLogText() : ""
        let prayerCount = viewModel.sortedEntries.count
        viewModel.clearLog()
        if shouldExport {
            onExportLog(logText, prayerCount)
        }
    }

    /// How long the AMEN! blink and its haptic pulses last.
    private static let amenFlashDuration: TimeInterval = 5.0

    /// Amen Alarm progress since the last prayer (0...1+), or nil when the alarm is off.
    /// Gated on the Phone toggle only — the progress bar, flash, and vibration are
    /// per-device, so the watch shows its own (driven by the synced fire date).
    /// After the AMEN! flash window passes, returns nil so the slider reverts to plain PRAY.
    private func alarmProgress(at now: Date) -> Double? {
        guard amenAlarmSettings.phoneEnabled else { return nil }
        let interval = amenAlarmSettings.duration.rawValue
        guard interval > 0 else { return nil }
        let elapsed = viewModel.elapsedSinceLastPrayer(at: now)
        if elapsed - interval > Self.amenFlashDuration { return nil }
        return elapsed / interval
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
        amenAlarmSettings: AmenAlarmSettings(),
        logExportSettings: LogExportSettings(),
        consent: AnalyticsConsent()
    )
}
