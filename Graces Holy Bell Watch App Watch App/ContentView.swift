import SwiftUI
import Combine

struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @Namespace private var prayerFigureNS

    var body: some View {
        NavigationStack {
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
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(Color.lcdBackground, for: .navigation)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
        }
        .persistentSystemOverlays(.hidden)
        .onReceive(connectivityManager.$latestState) { state in
            if let state {
                viewModel.apply(state)
            }
        }
    }
}
