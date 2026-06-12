import Foundation

/// Lightweight snapshot of the app state for WatchConnectivity transfer.
///
/// This is NOT a database object — it's a plain Codable struct, encoded to a
/// single property-list `Data` blob for `updateApplicationContext()` and
/// message replies. Used by both iPhone (to send state) and Watch (to receive
/// and display state). Both targets compile this same file, so the wire
/// format cannot drift between devices.
struct SyncedSessionState: Codable {

    /// "idle" or "active"
    let appState: String

    /// All prayer entries in the current/recent session.
    let entries: [SyncedEntry]

    /// The exact date/time the Amen Alarm should fire on the Watch.
    /// Nil when the alarm is disabled or the session is stopped/cleared.
    /// Recalculated as `lastPrayerTimestamp + alarmDuration` on every PRAY slide.
    let amenAlarmFireAt: Date?

    // MARK: - Dictionary Conversion

    private static let payloadKey = "state"

    /// Wraps the Codable encoding in a property-list dictionary for WatchConnectivity.
    func toDictionary() -> [String: Any] {
        guard let data = try? PropertyListEncoder().encode(self) else { return [:] }
        return [Self.payloadKey: data]
    }

    /// Decodes from a property-list dictionary received via WatchConnectivity.
    static func fromDictionary(_ dict: [String: Any]) -> SyncedSessionState? {
        guard let data = dict[payloadKey] as? Data else { return nil }
        return try? PropertyListDecoder().decode(SyncedSessionState.self, from: data)
    }
}

/// A single prayer entry as transferred via WatchConnectivity.
struct SyncedEntry: Codable {

    /// The wall clock time when PRAY was slid.
    let timestamp: Date

    /// Position in the session (0-based).
    let sequenceIndex: Int
}
