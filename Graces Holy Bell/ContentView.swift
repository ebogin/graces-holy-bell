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
    @State private var showSettings = false
    var connectivityManager: PhoneConnectivityManager?
    var settings: AppSettings

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let viewModel {
                    switch viewModel.appState {
                    case .idle:
                        IdleView(viewModel: viewModel)
                    case .active:
                        ActiveSessionView(viewModel: viewModel, settings: settings)
                    }
                } else {
                    ProgressView()
                }
            }

            // Settings gear button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            // Reschedule notification in case interval or destination changed
            viewModel?.rescheduleNotification()
        }) {
            SettingsView(settings: settings)
        }
        .task {
            if viewModel == nil {
                let vm = SessionViewModel(modelContext: modelContext, settings: settings)
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
    ContentView(settings: AppSettings())
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
