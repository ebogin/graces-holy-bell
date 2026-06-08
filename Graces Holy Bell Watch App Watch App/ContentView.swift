import SwiftUI
import Combine

struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @Namespace private var prayerFigureNS

    var body: some View {
        ZStack {
            switch viewModel.route {
            case .firstLaunch:
                WatchFirstLaunchView(viewModel: viewModel, namespace: prayerFigureNS)
                    .transition(.opacity)
            case .active:
                WatchActiveSessionView(viewModel: viewModel, namespace: prayerFigureNS)
                    .transition(.opacity)
            case .log:
                WatchLogView(viewModel: viewModel)
                    .transition(.opacity)
            case .idle:
                WatchIdleClearedView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: viewModel.route)
        .background(Color.lcdBackground)
        .ignoresSafeArea(edges: .bottom)
        .persistentSystemOverlays(.hidden)
        .onReceive(connectivityManager.$latestState) { state in
            if let state {
                viewModel.apply(state)
            }
        }
    }
}
