//
//  Graces_Holy_Bell_Watch_AppApp.swift
//  Graces Holy Bell Watch App Watch App
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI

@main
struct Graces_Holy_Bell_Watch_App_Watch_AppApp: App {

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
                        viewModel = WatchSessionViewModel(
                            connectivityManager: connectivityManager
                        )
                    }
            }
        }
    }
}
