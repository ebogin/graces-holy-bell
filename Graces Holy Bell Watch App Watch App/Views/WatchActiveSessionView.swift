import SwiftUI

/// Watch ACTIVE SESSION screen — translated from Figma node 238:53 (Watch Active Prayer v1.41).
/// All element positions come from WatchScreenLayout, shared with
/// WatchFirstLaunchView, so the figure/slider/bottom row never move
/// between the two screens.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    @State private var showStopConfirmation = false

    var body: some View {
        // Single per-second clock for the whole screen — the timer and the
        // slider's alarm progress both derive from one context.date.
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            screen(now: context.date)
        }
    }

    private func screen(now: Date) -> some View {
        WatchScreenLayout(figurePose: .praying) {

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
                            .frame(width: 24, height: 24)
                        Rectangle()
                            .fill(Color.lcdThumbText)
                            .frame(width: 11, height: 11)
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
