import Foundation

/// One post-hoc change the user made to the current session's log — a deleted
/// prayer or an edited prayer time. Not shown in the in-app log; included in
/// the saved Notes log so the record is honest about after-the-fact changes.
struct PrayerLogChange: Codable, Equatable {

    enum Kind: String, Codable {
        case deleted
        case timeEdited
    }

    let kind: Kind
    /// When the user made the change.
    let occurredAt: Date
    /// The prayer's timestamp before the change.
    let originalTimestamp: Date
    /// The new timestamp (time edits only).
    let newTimestamp: Date?
}

/// UserDefaults-backed store for the current session's change history.
/// Phone-only; reset whenever the session log is cleared.
struct PrayerLogChangeStore {

    private static let key = "prayer.sessionChanges"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PrayerLogChange] {
        guard let data = defaults.data(forKey: Self.key),
              let changes = try? JSONDecoder().decode([PrayerLogChange].self, from: data) else {
            return []
        }
        return changes
    }

    func append(_ change: PrayerLogChange) {
        var changes = load()
        changes.append(change)
        if let data = try? JSONEncoder().encode(changes) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
