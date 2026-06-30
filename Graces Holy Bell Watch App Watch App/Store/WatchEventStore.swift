import Foundation

/// Lightweight Codable event store for Watch-side prayer events.
/// Persisted as a JSON file in the Watch app's Application Support directory.
/// The phone uses SwiftData; the Watch uses this instead.
enum WatchEventStore {

    struct State: Codable {
        var events: [PrayerEvent] = []
        var lastClearedAt: Date?
        /// Last alarm duration synced from the phone (seconds).
        /// Used to recompute the fire date offline when the phone is unreachable.
        var lastSyncedAlarmInterval: TimeInterval?
    }

    static func load() -> State {
        guard let data = try? Data(contentsOf: storeURL),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    static func save(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("watchEvents.json")
    }
}
