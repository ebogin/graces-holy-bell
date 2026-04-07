//
//  ContentView.swift
//  Graces Holy Bell Watch App Watch App
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import Combine

/// Watch root view that routes between IDLE and ACTIVE screens.
///
/// Observes the WatchSessionViewModel and the WatchConnectivityManager
/// to update whenever new state arrives from the iPhone.
struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.appState {
                case .idle:
                    WatchIdleView(viewModel: viewModel)
                case .active:
                    WatchActiveSessionView(viewModel: viewModel)
                }
            }
        }
        // When new state arrives from iPhone, apply it to the ViewModel
        .onReceive(connectivityManager.$latestState) { state in
            if let state {
                viewModel.apply(state)
            }
        }
    }
}
