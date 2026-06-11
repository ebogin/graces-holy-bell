import Foundation

/// Formats Date values into wall clock time strings for the prayer log.
enum TimeFormatter {

    private static let wallClockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Formats a Date as wall clock time: "5:00 AM", "7:14 PM"
    static func wallClockString(from date: Date) -> String {
        wallClockFormatter.string(from: date)
    }
}
