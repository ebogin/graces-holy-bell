//
//  Graces_Holy_BellApp.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData

@main
struct Graces_Holy_BellApp: App {

    @State private var connectivityManager = PhoneConnectivityManager()
    @State private var settings = AppSettings()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(connectivityManager: connectivityManager, settings: settings)
        }
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self])
    }
}
