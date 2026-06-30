import Foundation

/// A single immutable prayer event. Compiles into both iPhone and Watch targets.
struct PrayerEvent: Codable, Equatable, Identifiable {

    let id: UUID
    let timestamp: Date
    let origin: Origin

    init(id: UUID = UUID(), timestamp: Date = .now, origin: Origin) {
        self.id = id
        self.timestamp = timestamp
        self.origin = origin
    }

    enum Origin: String, Codable {
        case phone
        case watch
    }
}
