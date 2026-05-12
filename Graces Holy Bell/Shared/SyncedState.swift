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

    /// When the session was stopped, or nil if still active.
    /// Used by Watch to compute frozen final duration in IDLE state.
    let sessionStoppedAt: Date?

    /// Whether there is an existing log (used for new-session confirmation).
    let hasExistingLog: Bool

    /// Suggested prayer interval in seconds (from AppSettings).
    /// Sent to Watch so it can display the countdown and schedule its own notification.
    let intervalSeconds: Double

    /// When true, the Watch should schedule its own local notification.
    /// When false, iPhone handles the notification.
    let notifyOnWatch: Bool

    // MARK: - Dictionary Conversion

    /// Converts to a property-list dictionary for WatchConnectivity.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "appState": appState,
            "hasExistingLog": hasExistingLog,
            "intervalSeconds": intervalSeconds,
            "notifyOnWatch": notifyOnWatch
        ]

        if let stoppedAt = sessionStoppedAt {
            dict["sessionStoppedAt"] = stoppedAt.timeIntervalSince1970
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
              let hasExistingLog = dict["hasExistingLog"] as? Bool,
              let entryDicts = dict["entries"] as? [[String: Any]] else {
            return nil
        }

        let stoppedAt: Date?
        if let stoppedAtInterval = dict["sessionStoppedAt"] as? TimeInterval {
            stoppedAt = Date(timeIntervalSince1970: stoppedAtInterval)
        } else {
            stoppedAt = nil
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

        let intervalSeconds = dict["intervalSeconds"] as? Double ?? 3600
        let notifyOnWatch = dict["notifyOnWatch"] as? Bool ?? false

        return SyncedSessionState(
            appState: appState,
            entries: entries,
            sessionStoppedAt: stoppedAt,
            hasExistingLog: hasExistingLog,
            intervalSeconds: intervalSeconds,
            notifyOnWatch: notifyOnWatch
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
