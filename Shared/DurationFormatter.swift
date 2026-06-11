import Foundation

/// Formats TimeInterval values into human-readable duration strings.
/// Used by both the live timer display and the prayer log durations.
enum DurationFormatter {

    /// Formats a TimeInterval as "Xh Ym Zs".
    /// Hours are omitted when zero. Minutes and seconds always show.
    /// Examples: "2h 14m 32s", "14m 00s", "0m 05s"
    static func string(from interval: TimeInterval) -> String {
        let totalSeconds = Int(max(interval, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m \(String(format: "%02d", seconds))s"
        } else {
            return "\(minutes)m \(String(format: "%02d", seconds))s"
        }
    }

    /// Formats a TimeInterval as "HH:MM:SS" for the large timer display.
    /// Always shows hours. Examples: "00:14:32", "02:14:32"
    static func timerString(from interval: TimeInterval) -> String {
        let totalSeconds = Int(max(interval, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
