import SwiftUI
import Combine

struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.route {
                case .firstLaunch:
                    WatchFirstLaunchView(viewModel: viewModel)
                        .transition(.opacity)
                case .active:
                    WatchActiveSessionView(viewModel: viewModel)
                        .transition(.opacity)
                case .log:
                    WatchLogView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.4), value: viewModel.route)
            .containerBackground(Color.lcdBackground, for: .navigation)
            // The navigation bar is hidden so screens can use the full height.
            // The system clock still draws top-right; each screen reserves
            // DesignSystem.Metrics.clockClearance at the top to stay clear of it.
            .toolbar(.hidden, for: .navigationBar)
        }
        .persistentSystemOverlays(.hidden)
        .onReceive(connectivityManager.$latestSnapshot) { snapshot in
            if let snapshot {
                viewModel.applySnapshot(snapshot)
            }
        }
    }
}
