import Foundation

// MARK: - SyncSnapshot (full state exchange)

/// Full active-state snapshot exchanged between iPhone and Watch.
/// Sent via updateApplicationContext (background) and as sendMessage replies (reachable).
/// The receiver merges this with its local state using SyncEngine.
struct SyncSnapshot: Codable {

    let events: [PrayerEvent]
    let lastClearedAt: Date?
    /// When the Amen Alarm should fire on the Watch. Nil when disabled/idle.
    let amenAlarmFireAt: Date?

    private static let payloadKey = "snapshot"

    func toDictionary() -> [String: Any] {
        guard let data = try? PropertyListEncoder().encode(self) else { return [:] }
        return [Self.payloadKey: data]
    }

    static func fromDictionary(_ dict: [String: Any]) -> SyncSnapshot? {
        guard let data = dict[payloadKey] as? Data else { return nil }
        return try? PropertyListDecoder().decode(SyncSnapshot.self, from: data)
    }
}

// MARK: - EventMessage (single prayer, transferUserInfo)

/// Carries one watch-origin prayer event for offline-safe incremental sync.
struct EventMessage {
    let event: PrayerEvent

    func toUserInfo() -> [String: Any] {
        [
            "msg": "event",
            "id": event.id.uuidString,
            "timestamp": event.timestamp,
            "origin": event.origin.rawValue
        ]
    }

    static func fromUserInfo(_ dict: [String: Any]) -> EventMessage? {
        guard dict["msg"] as? String == "event",
              let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = dict["timestamp"] as? Date,
              let originString = dict["origin"] as? String,
              let origin = PrayerEvent.Origin(rawValue: originString) else { return nil }
        return EventMessage(event: PrayerEvent(id: id, timestamp: timestamp, origin: origin))
    }
}

// MARK: - ClearMessage (clear epoch, transferUserInfo)

/// Carries a clear-epoch timestamp so the receiving device wipes its pre-clear events.
struct ClearMessage {
    let clearedAt: Date

    func toUserInfo() -> [String: Any] {
        ["msg": "clear", "clearedAt": clearedAt]
    }

    static func fromUserInfo(_ dict: [String: Any]) -> ClearMessage? {
        guard dict["msg"] as? String == "clear",
              let clearedAt = dict["clearedAt"] as? Date else { return nil }
        return ClearMessage(clearedAt: clearedAt)
    }
}

// MARK: - Analytics proxy (unchanged)

/// Carry a Watch-originated analytics event to the phone's transport.
/// Distinct from the sync messages — the phone routes it to analytics rather than the merge path.
enum WatchAnalyticsProxy {
    static func prayerLogViewedPayload(at timestamp: Date) -> [String: Any] {
        ["analyticsEvent": "prayer_log_viewed", "timestamp": timestamp]
    }
    static func isPrayerLogViewed(_ dict: [String: Any]) -> Date? {
        guard dict["analyticsEvent"] as? String == "prayer_log_viewed",
              let ts = dict["timestamp"] as? Date else { return nil }
        return ts
    }
}
