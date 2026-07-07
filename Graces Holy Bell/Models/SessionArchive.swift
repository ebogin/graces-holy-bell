import CryptoKit
import Foundation

/// One prayer inside an archived (ended) session.
struct ArchivedPrayer: Codable, Equatable {
    let timestamp: Date
    let note: String?
}

/// A completed prayer session, frozen at the moment the log was cleared.
/// Includes the change history (deleted / re-timed prayers) so the archive
/// is honest about after-the-fact edits, same as the Notes export.
struct ArchivedSession: Codable, Equatable, Identifiable {
    let id: UUID
    let endedAt: Date
    let prayers: [ArchivedPrayer]
    let changes: [PrayerLogChange]

    /// Session start — the first prayer's time (endedAt for a defensive empty session).
    var startedAt: Date {
        prayers.first?.timestamp ?? endedAt
    }

    /// Deterministic identity derived from the prayers themselves, so archiving
    /// the same ended session twice — e.g. a local clear racing the Watch's echo
    /// of that clear across two sync channels — is idempotent:
    /// `SessionArchiveStore.append` skips an id it already holds. Uses the exact
    /// bit patterns of the timestamps, which both archive paths read from the
    /// same stored `Date`s.
    static func deterministicID(prayerTimestamps: [Date]) -> UUID {
        var hasher = SHA256()
        for timestamp in prayerTimestamps.sorted() {
            withUnsafeBytes(of: timestamp.timeIntervalSinceReferenceDate.bitPattern) {
                hasher.update(bufferPointer: $0)
            }
        }
        let digest = Array(hasher.finalize())
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}

/// JSON-file archive of past sessions (phone-only, like the Notes export).
/// Kept out of the SwiftData prayer store on purpose: history is append-only
/// display data and must never complicate the live store's schema/migrations.
struct SessionArchiveStore {

    /// Newest sessions kept when the archive is trimmed.
    private static let maxSessions = 500

    private let fileURL: URL

    /// Production archive location: Application Support/sessionArchive.json.
    init(directory: URL? = nil) {
        let dir = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = dir.appendingPathComponent("sessionArchive.json")
    }

    func load() -> [ArchivedSession] {
        guard let data = try? Data(contentsOf: fileURL),
              let sessions = try? JSONDecoder().decode([ArchivedSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func append(_ session: ArchivedSession) {
        var sessions = load()
        // Idempotent: the same ended session (deterministic id) archives once,
        // no matter how many sync channels replay its clear.
        guard !sessions.contains(where: { $0.id == session.id }) else { return }
        sessions.append(session)
        if sessions.count > Self.maxSessions {
            sessions.removeFirst(sessions.count - Self.maxSessions)
        }
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Sessions grouped by the calendar day they STARTED, newest day first;
    /// sessions within a day are oldest first (reads like the day's timeline).
    func sessionsByDay(calendar: Calendar = .current) -> [(day: Date, sessions: [ArchivedSession])] {
        let grouped = Dictionary(grouping: load()) { calendar.startOfDay(for: $0.startedAt) }
        return grouped
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startedAt < $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }
}
