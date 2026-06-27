import Foundation

/// Durable analytics-only state that must survive across launches, kept separate
/// from the app's own SwiftData/UserDefaults so it never affects app behavior.
///
/// - `installDate`: set once on the first ever launch (the `first_seen` anchor).
/// - `closedSessionStart`: the `startedAt` of the most recently *terminated*
///   session (via `session_ended` or a synthesized `session_abandoned`). Used to
///   enforce no-double-close across launches and the replace path.
protocol AnalyticsStateStore: AnyObject {
    var installDate: Date? { get set }
    var closedSessionStart: Date? { get set }
}

/// UserDefaults-backed store on an injectable suite (tests never touch `.standard`).
final class UserDefaultsAnalyticsStateStore: AnalyticsStateStore {
    private let defaults: UserDefaults
    private enum Keys {
        static let installDate = "analytics.install_date"
        static let closedSessionStart = "analytics.closed_session_start"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var installDate: Date? {
        get { defaults.object(forKey: Keys.installDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.installDate) }
    }

    var closedSessionStart: Date? {
        get { defaults.object(forKey: Keys.closedSessionStart) as? Date }
        set { defaults.set(newValue, forKey: Keys.closedSessionStart) }
    }
}
