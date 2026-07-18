//
//  Graces_Holy_BellApp.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData
import CoreText
import UserNotifications
import os

@main
struct Graces_Holy_BellApp: App {

    @State private var connectivityManager = PhoneConnectivityManager()
    /// Notification-tap router. Created and installed as the notification
    /// center's delegate here — during app launch — so a cold start from an
    /// Amen Alarm tap is never missed. The tap callback itself is wired up
    /// later, in ContentView's setup (the tap is buffered until then).
    /// Static so a re-created App value keeps the already-wired instance.
    private static let sharedNotificationForwarder = NotificationEventForwarder()
    private let notificationForwarder = Graces_Holy_BellApp.sharedNotificationForwarder

    private let modelContainer: ModelContainer
    /// True when the store could not be opened/migrated and was recreated from
    /// scratch (data loss). Surfaced to analytics once the service exists.
    private let storeWasRecovered: Bool

    init() {
        if let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        UNUserNotificationCenter.current().delegate = notificationForwarder
        (modelContainer, storeWasRecovered) = Self.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                connectivityManager: connectivityManager,
                notificationForwarder: notificationForwarder,
                storeWasRecovered: storeWasRecovered
            )
        }
        .modelContainer(modelContainer)
    }

    /// Opens the store through `PrayerMigrationPlan` (1.41 stores migrate in
    /// place). If that still fails, destroys the store files and starts fresh:
    /// losing one (ephemeral, usually small) log beats the 1.42 failure mode
    /// where the app ran against a store that never loaded and silently dropped
    /// every write. A `.modelContainer(for:)` failure does NOT crash the app,
    /// so without this fallback the failure is invisible.
    ///
    /// **Locked-device guard:** a background launch before the device is
    /// unlocked (a WatchConnectivity wake, prewarming) can't read the store at
    /// all — data protection, not corruption. 1.43 treated that as corruption:
    /// it destroyed the store files, failed again, and hit the `fatalError`
    /// (crash log FF343A97, "Non UI" role, assertion at the old line 74). Now
    /// an unreadable-but-present store skips the destroy entirely and serves a
    /// throwaway in-memory container for this (background, UI-less) process;
    /// the next unlocked launch opens the real store untouched.
    private static func makeModelContainer() -> (ModelContainer, recovered: Bool) {
        let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell", category: "persistence")
        let schema = Schema(versionedSchema: PrayerSchemaV3.self)
        let config = ModelConfiguration(schema: schema)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PrayerMigrationPlan.self,
                configurations: [config]
            )
            return (container, recovered: false)
        } catch {
            logger.fault("Store failed to open/migrate: \(error, privacy: .public)")
        }

        // Transient, not corruption: the store file exists but can't be read
        // (device locked before first unlock). Never destroy real data over a
        // passing condition — serve an in-memory container for this process.
        if storeExistsButIsUnreadable(at: config.url) {
            logger.fault("Store present but unreadable (likely locked device) — using an in-memory container for this launch.")
            return (makeInMemoryContainer(schema: schema), recovered: false)
        }

        // Last resort: remove the store (plus SQLite sidecar files) and retry.
        logger.fault("Store unrecoverable; destroying and recreating.")
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
            // Even a fresh store failed. Crashing here (pre-1.54) produced real
            // background-launch crash reports and helps nobody — run on an
            // in-memory container instead so the process at least stays alive.
            logger.fault("Fresh store creation failed: \(error, privacy: .public) — using an in-memory container.")
            return (makeInMemoryContainer(schema: schema), recovered: true)
        }
    }

    /// True when the store file is on disk but can't actually be opened for
    /// reading — the signature of data protection on a locked device (the
    /// catch-all for EPERM-style failures, as distinct from a missing or
    /// corrupt store).
    private static func storeExistsButIsUnreadable(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return true }
        try? handle.close()
        return false
    }

    /// A schema-matching container with no persistence — keeps a background,
    /// UI-less process functional without ever touching the on-disk store.
    /// Writes made against it vanish with the process, which beats both
    /// crashing and destroying the user's real data.
    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            // An in-memory container has no I/O to fail on; if even this
            // throws, something is fundamentally broken with the schema.
            fatalError("Unable to create an in-memory prayer store: \(error)")
        }
    }
}
