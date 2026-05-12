import SwiftUI

/// Watch ACTIVE SESSION screen — timer, animated figure, log, PRAY slider, STOP button.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    @State private var showStopConfirmation = false

    var body: some View {
        ZStack {
            Color.lcdBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Title
                    Text("Grace's\nHoly Bell")
                        .font(.pixelFont(6))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    // Live timer
                    WatchLiveTimerView(viewModel: viewModel)
                        .padding(.top, 8)

                    // Animated praying figure
                    WatchPrayingFigureView(pose: .praying, scale: 1.4)
                        .padding(.top, 6)

                    // PRAY slider
                    WatchPraySlider {
                        viewModel.sendPray()
                    }
                    .padding(.top, 10)

                    // Divider
                    Rectangle()
                        .fill(Color.lcdDark)
                        .frame(height: 2)
                        .padding(.vertical, 6)

                    // Prayer log
                    WatchPrayerLogView(viewModel: viewModel)

                    // Octagon STOP button
                    Button {
                        showStopConfirmation = true
                    } label: {
                        ZStack {
                            Octagon()
                                .fill(Color.lcdDark)
                                .frame(width: 34, height: 34)
                            Rectangle()
                                .fill(Color.lcdThumbText)
                                .frame(width: 11, height: 11)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 8)
            }
        }
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
