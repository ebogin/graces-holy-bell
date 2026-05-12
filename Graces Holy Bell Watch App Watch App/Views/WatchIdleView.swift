import SwiftUI

/// Watch IDLE screen — LCD green background, pixel art, START PRAYER slider.
struct WatchIdleView: View {

    let viewModel: WatchSessionViewModel
    @State private var showNewSessionConfirmation = false

    var body: some View {
        ZStack {
            Color.lcdBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Title
                    Text("Grace's\nHoly Bell")
                        .font(.pixelFont(7))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    // Status label
                    Text("SESSION ENDED")
                        .font(.pixelFont(5))
                        .foregroundStyle(Color.lcdMid)
                        .padding(.top, 6)

                    // Praying figure
                    WatchPrayingFigureView(pose: .idle, scale: 1.4)
                        .padding(.top, 8)

                    // START PRAYER slider
                    WatchPraySlider {
                        if viewModel.hasExistingLog {
                            showNewSessionConfirmation = true
                        } else {
                            viewModel.sendStart()
                        }
                    }
                    .padding(.top, 10)

                    // Divider
                    Rectangle()
                        .fill(Color.lcdDark)
                        .frame(height: 2)
                        .padding(.vertical, 8)

                    // Previous log
                    if viewModel.hasExistingLog {
                        WatchPrayerLogView(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .confirmationDialog(
            "Start new session?",
            isPresented: $showNewSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start New", role: .destructive) { viewModel.sendStart() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Previous log will be cleared.")
        }
    }
}
