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
                        #if DEBUG
                        seedWatchPrayerLogIfRequested()
                        #endif
                        let vm = WatchSessionViewModel(
                            connectivityManager: connectivityManager
                        )
                        viewModel = vm
                        // Pull fresh state from the phone on launch.
                        vm.syncNow()
                    }
            }
        }
        .persistentSystemOverlays(.hidden)
    }
}

#if DEBUG
/// Screenshot-only frozen clock for the Watch ACTIVE / LOG screens. When set (by
/// the seed below), those screens render against this fixed "now" instead of the
/// live clock so timers show an exact, non-ticking value for a still capture.
enum ScreenshotClock {
    static var fixedNow: Date?
}

/// App Store screenshot seeding for the Watch. When launched with
/// `--seed-prayer-log`, replace the Watch event store with three fixed prayers —
/// 11:15 PM / 12:46 AM / 2:31 AM (gaps 1h 31m / 1h 45m) — and freeze the screen
/// clock at 5m 22s past the last prayer so the "since last prayer" timer reads a
/// stable 00:05:22. Mirrors the iPhone seed. Stripped from Release builds.
private func seedWatchPrayerLogIfRequested() {
    guard ProcessInfo.processInfo.arguments.contains("--seed-prayer-log") else { return }

    // First prayer at 11:15 PM local; use the next occurrence of 23:15.
    let now = Date()
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = 23
    components.minute = 15
    components.second = 0
    var firstPrayer = calendar.date(from: components) ?? now
    if firstPrayer <= now {
        firstPrayer = calendar.date(byAdding: .day, value: 1, to: firstPrayer) ?? firstPrayer
    }
    let events = [
        PrayerEvent(id: UUID(), timestamp: firstPrayer, origin: .watch),
        PrayerEvent(id: UUID(), timestamp: firstPrayer.addingTimeInterval(1 * 3600 + 31 * 60), origin: .watch),
        PrayerEvent(id: UUID(), timestamp: firstPrayer.addingTimeInterval(3 * 3600 + 16 * 60), origin: .watch)
    ]
    WatchEventStore.save(WatchEventStore.State(events: events, lastClearedAt: nil, lastSyncedAlarmInterval: nil))
    ScreenshotClock.fixedNow = events[2].timestamp.addingTimeInterval(5 * 60 + 22)
}
#endif
