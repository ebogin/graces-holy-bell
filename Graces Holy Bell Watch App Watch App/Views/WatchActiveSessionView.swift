import SwiftUI
import WatchKit

/// Watch ACTIVE SESSION screen — fixed layout with timer, animated figure, PRAY slider, STOP + LOG buttons.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    var namespace: Namespace.ID
    @State private var showStopConfirmation = false

    private var figureHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 78 : 60
    }

    var body: some View {
        VStack(spacing: 3) {
            // Title
            Text("GRACE'S HOLY BELL")
                .font(.pixelFont(8.5))
                .foregroundStyle(Color.lcdMid)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 10)

            // Live timer + label
            WatchLiveTimerView(viewModel: viewModel)

            // Animated figure — fills remaining space
            WatchPrayingFigureView(pose: .praying, height: figureHeight)
                .matchedGeometryEffect(id: "prayFigure", in: namespace)
                .frame(maxHeight: .infinity)

            // PRAY slider
            WatchPraySlider(label: "PRAY") {
                viewModel.sendPray()
            }

            // Bottom row: STOP centered, LOG floating right
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
                    Spacer()
                    LogBadgeButton(count: viewModel.sortedEntries.count) {
                        viewModel.showingLog = true
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "End session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) { viewModel.sendStop() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clock stops. No final prayer recorded.")
        }
    }
}
