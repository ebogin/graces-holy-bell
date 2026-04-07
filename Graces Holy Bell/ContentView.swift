//
//  ContentView.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData

/// Root view that routes between IDLE and ACTIVE screens based on the ViewModel's state.
///
/// This view is intentionally thin — it creates the ViewModel and delegates
/// all display and interaction to IdleView or ActiveSessionView.
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SessionViewModel?
    var connectivityManager: PhoneConnectivityManager?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.appState {
                case .idle:
                    IdleView(viewModel: viewModel)
                case .active:
                    ActiveSessionView(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = SessionViewModel(modelContext: modelContext)
                // Wire up Watch connectivity: ViewModel notifies manager after each mutation
                if let connectivityManager {
                    vm.onStateChanged = { [weak connectivityManager] in
                        connectivityManager?.sendStateToWatch()
                    }
                    connectivityManager.configure(with: vm)
                }
                viewModel = vm
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
