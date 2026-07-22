import SwiftUI

/// Watch ACTIVE SESSION screen — translated from Figma node 238:53 (Watch Active Prayer v1.41).
/// All element positions come from WatchScreenLayout, shared with
/// WatchFirstLaunchView, so the figure/slider/bottom row never move
/// between the two screens.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    /// Remotely-configurable per-prayer action manifest (see ANIMATIONS.md),
    /// supplied by WatchContentView. Defaulted so previews stay simple.
    var animations: PrayerActionsConfig = .bundledDefault
    @State private var showStopConfirmation = false
    /// Fire date of the last AMEN takeover the user dismissed — a new fire
    /// (next alarm interval) presents the takeover again.
    @State private var acknowledgedFireDate: Date?
    /// The prayer action currently playing in the figure's slot (placeholder
    /// scaffolding), or nil while the figure is simply praying.
    @State private var activeAction: ResolvedPrayerAction?
    /// Highest prayer index already played — so each swipe fires once and
    /// re-appearing the screen doesn't replay.
    @State private var lastTriggeredIndex = 0

    var body: some View {
        // Single per-second clock for the whole screen — the timer and the
        // slider's alarm progress both derive from one context.date.
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
        ZStack {
            mainScreen(now: now)

            // Full-screen AMEN takeover: bell tower ringing, 30s of dot-dot-dot
            // wrist haptics, and (when enabled) the clanging bell. Tap dismisses.
            if let fireAt = takeoverFireDate(at: now), acknowledgedFireDate != fireAt {
                WatchAmenTakeoverView(
                    fireDate: fireAt,
                    soundEnabled: viewModel.amenSoundEnabled
                ) {
                    acknowledgedFireDate = fireAt
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: takeoverFireDate(at: now))
        // Per-prayer action placeholder: fire on appear (covers the first
        // prayer, logged on the start screen before this view existed) and on
        // each subsequent count change (later swipes).
        .onAppear { syncPrayerAction() }
        .onChange(of: viewModel.sortedEntries.count) { _, _ in syncPrayerAction() }
        // Hold the action for its duration, then return to praying. A new swipe
        // mid-action changes activeAction, cancelling this and restarting.
        .task(id: activeAction) {
            guard let action = activeAction else { return }
            try? await Task.sleep(for: .seconds(action.durationSeconds))
            guard !Task.isCancelled else { return }
            activeAction = nil
        }
    }

    /// A prayer whose timestamp is older than this when the screen (re)appears
    /// is treated as pre-existing (relaunch, returning from a sheet) and does
    /// NOT replay its action — only a fresh swipe does.
    private static let actionTriggerRecency: TimeInterval = 3

    /// Plays the placeholder action for the newest prayer, exactly once per
    /// swipe. Beyond the configured sequence length, `action(forPrayerIndex:)`
    /// returns nil and the figure simply keeps praying.
    private func syncPrayerAction() {
        guard FeatureFlags.prayerActionsEnabled else { return }
        let count = viewModel.sortedEntries.count
        guard count > lastTriggeredIndex else {
            // Count dropped (sync/merge) or unchanged — realign, never replay.
            lastTriggeredIndex = min(lastTriggeredIndex, count)
            return
        }
        let justHappened = viewModel.lastPrayerTimestamp
            .map { Date().timeIntervalSince($0) < Self.actionTriggerRecency } ?? false
        lastTriggeredIndex = count
        guard justHappened,
              let action = animations.action(forPrayerIndex: count)
        else { return }
        activeAction = action
    }

    /// How long after the fire moment the takeover keeps presenting — opening
    /// the app well after the alarm still shows AMEN until acknowledged.
    private static let takeoverWindow: TimeInterval = 600

    /// The current alarm fire date when the takeover should be up, or nil.
    private func takeoverFireDate(at now: Date) -> Date? {
        // Off: no takeover, so WatchAmenTakeoverView never mounts and its
        // 30-second dot-dot-dot haptic pattern never starts. The Watch is left
        // with the slider's AMEN! blink. See FeatureFlags.amenTakeoverEnabled.
        guard FeatureFlags.amenTakeoverEnabled else { return nil }
        guard let fireAt = viewModel.amenAlarmFireAt,
              now >= fireAt,
              now.timeIntervalSince(fireAt) <= Self.takeoverWindow else { return nil }
        return fireAt
    }

    private func mainScreen(now: Date) -> some View {
        WatchScreenLayout(figurePose: .praying, prayerAction: activeAction) {

            // Header: small title over the live timer + "SINCE LAST PRAYER"
            WatchSessionHeader(viewModel: viewModel, now: now)

        } slider: {

            // Doubles as Amen Alarm progress bar when the alarm is on
            WatchPraySlider(
                label: "PRAY",
                alarmProgress: viewModel.alarmProgress(at: now)
            ) {
                viewModel.sendPray()
            }

        } bottomRow: {

            // Stop centered, log badge trailing
            ZStack {
                Button {
                    showStopConfirmation = true
                } label: {
                    ZStack {
                        Octagon()
                            .fill(Color.lcdDark)
                            .frame(width: 21, height: 21)
                        Rectangle()
                            .fill(Color.lcdThumbText)
                            .frame(width: 10, height: 10)
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    ShareButton {
                        viewModel.showingShare = true
                    }
                    .accessibilityIdentifier("watch-share-button")
                    Spacer()
                    LogBadgeButton(count: viewModel.sortedEntries.count) {
                        viewModel.showingLog = true
                    }
                }
                .padding(.horizontal, DesignSystem.Metrics.cornerButtonInset)
            }
        }
        .confirmationDialog(
            "End Praying?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Log", role: .destructive) { viewModel.sendClearLog() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clear the log and start fresh. This CANNOT BE UNDONE")
        }
    }
}
