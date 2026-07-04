import Foundation
import Observation

/// Persisted user preference for the prayer-timer Live Activity.
///
/// Backed by UserDefaults — durable across launches. Default ON: the feature
/// was requested by testers and only appears during an active session.
@Observable
final class LiveActivitySettings {

    /// Invoked after the setting changes — used to start/end the Live Activity
    /// immediately instead of waiting for the next prayer.
    @ObservationIgnored var onChange: (() -> Void)?

    /// Whether the Lock Screen / Dynamic Island timer is shown during a session.
    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Keys.enabled)
            onChange?()
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: Keys.enabled) != nil {
            self.enabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        } else {
            self.enabled = true
        }
    }

    private enum Keys {
        static let enabled = "liveActivity.enabled"
    }
}
