//
//  Graces_Holy_BellApp.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData
import CoreText
import os

@main
struct Graces_Holy_BellApp: App {

    @State private var connectivityManager = PhoneConnectivityManager()

    private let modelContainer: ModelContainer
    /// True when the store could not be opened/migrated and was recreated from
    /// scratch (data loss). Surfaced to analytics once the service exists.
    private let storeWasRecovered: Bool

    init() {
        if let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        (modelContainer, storeWasRecovered) = Self.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(connectivityManager: connectivityManager, storeWasRecovered: storeWasRecovered)
        }
        .modelContainer(modelContainer)
    }

    /// Opens the store through `PrayerMigrationPlan` (1.41 stores migrate in
    /// place). If that still fails, destroys the store files and starts fresh:
    /// losing one (ephemeral, usually small) log beats the 1.42 failure mode
    /// where the app ran against a store that never loaded and silently dropped
    /// every write. A `.modelContainer(for:)` failure does NOT crash the app,
    /// so without this fallback the failure is invisible.
    private static func makeModelContainer() -> (ModelContainer, recovered: Bool) {
        let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell", category: "persistence")
        let schema = Schema(versionedSchema: PrayerSchemaV2.self)
        let config = ModelConfiguration(schema: schema)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PrayerMigrationPlan.self,
                configurations: [config]
            )
            return (container, recovered: false)
        } catch {
            logger.fault("Store failed to open/migrate; destroying and recreating: \(error, privacy: .public)")
        }

        // Last resort: remove the store (plus SQLite sidecar files) and retry.
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(fileURLWithPath: config.url.path + suffix))
        }
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PrayerMigrationPlan.self,
                configurations: [config]
            )
            return (container, recovered: true)
        } catch {
            // A fresh store failing to create is unrecoverable and would otherwise
            // silently drop all data — crash loudly instead.
            fatalError("Unable to create a fresh prayer store: \(error)")
        }
    }
}
