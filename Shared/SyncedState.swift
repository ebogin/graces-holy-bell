import Foundation

/// Lightweight snapshot of the app state for WatchConnectivity transfer.
///
/// This is NOT a database object — it's a plain Codable struct that serializes
/// to/from a dictionary for `updateApplicationContext()` and `transferUserInfo()`.
/// Used by both iPhone (to send state) and Watch (to receive and display state).
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

    /// Converts to a property-list dictionary for WatchConnectivity.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "appState": appState
        ]

        if let fireAt = amenAlarmFireAt {
            dict["amenAlarmFireAt"] = fireAt.timeIntervalSince1970
        }

        let entryDicts: [[String: Any]] = entries.map { entry in
            [
                "timestamp": entry.timestamp.timeIntervalSince1970,
                "sequenceIndex": entry.sequenceIndex
            ]
        }
        dict["entries"] = entryDicts

        return dict
    }

    /// Creates from a property-list dictionary received via WatchConnectivity.
    static func fromDictionary(_ dict: [String: Any]) -> SyncedSessionState? {
        guard let appState = dict["appState"] as? String,
              let entryDicts = dict["entries"] as? [[String: Any]] else {
            return nil
        }

        let entries = entryDicts.compactMap { entryDict -> SyncedEntry? in
            guard let timestamp = entryDict["timestamp"] as? TimeInterval,
                  let sequenceIndex = entryDict["sequenceIndex"] as? Int else {
                return nil
            }
            return SyncedEntry(
                timestamp: Date(timeIntervalSince1970: timestamp),
                sequenceIndex: sequenceIndex
            )
        }

        let amenAlarmFireAt: Date?
        if let fireAtInterval = dict["amenAlarmFireAt"] as? TimeInterval {
            amenAlarmFireAt = Date(timeIntervalSince1970: fireAtInterval)
        } else {
            amenAlarmFireAt = nil
        }

        return SyncedSessionState(
            appState: appState,
            entries: entries,
            amenAlarmFireAt: amenAlarmFireAt
        )
    }
}

/// A single prayer entry as transferred via WatchConnectivity.
struct SyncedEntry: Codable {

    /// The wall clock time when PRAY was slid.
    let timestamp: Date

    /// Position in the session (0-based).
    let sequenceIndex: Int
}
