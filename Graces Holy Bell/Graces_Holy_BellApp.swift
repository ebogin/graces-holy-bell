//
//  Graces_Holy_BellApp.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData
import CoreText

@main
struct Graces_Holy_BellApp: App {

    @State private var connectivityManager = PhoneConnectivityManager()

    init() {
        if let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(connectivityManager: connectivityManager)
        }
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self])
    }
}
