import Foundation
import Observation

/// Persisted preference for saving the session log to the Notes app when a
/// session ends. UserDefaults-backed, same pattern as AmenAlarmSettings.
@Observable
final class LogExportSettings {

    /// Invoked after the setting changes (analytics).
    @ObservationIgnored var onChange: ((Bool) -> Void)?

    /// When on, ending a session ("Clear Log") offers the composed session log
    /// to the share sheet so it can be appended to a note in the Notes app.
    var saveToNotesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(saveToNotesEnabled, forKey: Keys.saveToNotes)
            onChange?(saveToNotesEnabled)
        }
    }

    init() {
        self.saveToNotesEnabled = UserDefaults.standard.bool(forKey: Keys.saveToNotes)
    }

    private enum Keys {
        static let saveToNotes = "logExport.saveToNotesEnabled"
    }
}
