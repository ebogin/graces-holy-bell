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
    /// The phone's Watch-alarm *setting*: the alarm interval in seconds, or nil
    /// when the Watch alarm is disabled. Explicit because `amenAlarmFireAt`
    /// alone cannot distinguish "disabled" from "idle" — the Watch needs this
    /// to turn its alarm OFF instead of re-arming from a stale interval.
    /// Optional-with-default so payloads minted before the field decode cleanly.
    var watchAlarmInterval: TimeInterval? = nil
    /// Whether the alarm should also play the loud clanging bell on the Watch.
    /// Optional with a default so snapshots from builds without the field
    /// still decode (missing key → nil → treated as off).
    var amenAlarmSoundEnabled: Bool? = nil

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
        var dict: [String: Any] = [
            "msg": "event",
            "id": event.id.uuidString,
            "timestamp": event.timestamp,
            "origin": event.origin.rawValue,
            "updatedAt": event.updatedAt,
            "isDeleted": event.isDeleted
        ]
        if let note = event.note {
            dict["note"] = note
        }
        return dict
    }

    static func fromUserInfo(_ dict: [String: Any]) -> EventMessage? {
        guard dict["msg"] as? String == "event",
              let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = dict["timestamp"] as? Date,
              let originString = dict["origin"] as? String,
              let origin = PrayerEvent.Origin(rawValue: originString) else { return nil }
        let updatedAt = dict["updatedAt"] as? Date ?? timestamp
        return EventMessage(event: PrayerEvent(
            id: id,
            timestamp: timestamp,
            origin: origin,
            updatedAt: updatedAt,
            // Carry the full event so a tombstone or note is never silently
            // reconstructed as a live, note-less prayer and resurrected by LWW.
            isDeleted: dict["isDeleted"] as? Bool ?? false,
            note: dict["note"] as? String
        ))
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

    // MARK: - Share surface (additive)

    /// Carries a Watch-origin `share_screen_opened` / `qr_displayed` to the
    /// phone, including the Watch's own `referralCode` — each device mints its
    /// own code (see `WaitlistLink`), so it rides along with the timestamp
    /// rather than being recomputed on the phone.
    static func shareScreenOpenedPayload(referralCode: String, at timestamp: Date) -> [String: Any] {
        ["analyticsEvent": "share_screen_opened", "timestamp": timestamp, "referralCode": referralCode]
    }
    static func isShareScreenOpened(_ dict: [String: Any]) -> (referralCode: String, timestamp: Date)? {
        guard dict["analyticsEvent"] as? String == "share_screen_opened",
              let ts = dict["timestamp"] as? Date,
              let code = dict["referralCode"] as? String else { return nil }
        return (code, ts)
    }

    static func qrDisplayedPayload(referralCode: String, at timestamp: Date) -> [String: Any] {
        ["analyticsEvent": "qr_displayed", "timestamp": timestamp, "referralCode": referralCode]
    }
    static func isQRDisplayed(_ dict: [String: Any]) -> (referralCode: String, timestamp: Date)? {
        guard dict["analyticsEvent"] as? String == "qr_displayed",
              let ts = dict["timestamp"] as? Date,
              let code = dict["referralCode"] as? String else { return nil }
        return (code, ts)
    }
}
