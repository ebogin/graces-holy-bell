import Foundation
import Observation

/// Persisted user preferences for the ADVANCED settings section.
///
/// Backed by UserDefaults — changes are durable across launches.
/// Defaults: Prayer Log Editing OFF.
@Observable
final class AdvancedSettings {

    /// Invoked after the setting changes (analytics / side effects).
    @ObservationIgnored var onChange: ((Bool) -> Void)?

    /// Master switch for the phone-only prayer-log editing features: long-press
    /// to edit a prayer's time/intention/deletion, the "HOLD TO EDIT" cue, the
    /// per-row edit chevron, and the intention icon. When off, the log is
    /// display-only and none of those affordances appear.
    var prayerLogEditingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(prayerLogEditingEnabled, forKey: Keys.prayerLogEditing)
            onChange?(prayerLogEditingEnabled)
        }
    }

    init() {
        self.prayerLogEditingEnabled = UserDefaults.standard.bool(forKey: Keys.prayerLogEditing)
    }

    private enum Keys {
        static let prayerLogEditing = "advanced.prayerLogEditingEnabled"
    }
}
