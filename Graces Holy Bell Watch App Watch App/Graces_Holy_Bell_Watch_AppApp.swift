//
//  Graces_Holy_Bell_Watch_AppApp.swift
//  Graces Holy Bell Watch App Watch App
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import CoreText

@main
struct Graces_Holy_Bell_Watch_App_Watch_AppApp: App {

    init() {
        if let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    @StateObject private var connectivityManager = WatchConnectivityManager()
    @State private var viewModel: WatchSessionViewModel?

    var body: some Scene {
        WindowGroup {
            if let viewModel {
                WatchContentView(
                    viewModel: viewModel,
                    connectivityManager: connectivityManager
                )
            } else {
                ProgressView()
                    .task {
                        let vm = WatchSessionViewModel(connectivityManager: connectivityManager)
                        #if DEBUG
                        if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
                            vm.apply(SyncedSessionState(
                                appState: "active",
                                entries: [SyncedEntry(timestamp: Date().addingTimeInterval(-30), sequenceIndex: 0)],
                                sessionStoppedAt: nil,
                                hasExistingLog: false
                            ))
                        }
                        #endif
                        viewModel = vm
                    }
            }
        }
        .persistentSystemOverlays(.hidden)
    }
}
