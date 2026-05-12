import Foundation
import Observation

@Observable
final class AppSettings {

    var intervalSeconds: Double {
        didSet { UserDefaults.standard.set(intervalSeconds, forKey: "prayerIntervalSeconds") }
    }

    var notifyOnWatch: Bool {
        didSet { UserDefaults.standard.set(notifyOnWatch, forKey: "notifyOnWatch") }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: "prayerIntervalSeconds")
        intervalSeconds = stored > 0 ? stored : 3600
        notifyOnWatch = UserDefaults.standard.bool(forKey: "notifyOnWatch")
    }

    // MARK: - Interval Options

    struct IntervalOption: Identifiable {
        let id: Double
        let label: String
        var seconds: Double { id }
    }

    static let intervalOptions: [IntervalOption] = [
        IntervalOption(id: 900,  label: "15 minutes"),
        IntervalOption(id: 1800, label: "30 minutes"),
        IntervalOption(id: 2700, label: "45 minutes"),
        IntervalOption(id: 3600, label: "1 hour"),
        IntervalOption(id: 5400, label: "1.5 hours"),
        IntervalOption(id: 7200, label: "2 hours"),
    ]
}
