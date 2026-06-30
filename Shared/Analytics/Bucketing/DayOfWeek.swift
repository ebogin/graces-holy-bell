import Foundation

/// Maps a timestamp to its weekday label for the `day_of_week` property.
///
/// Emits only the day name; the "Weekend Warrior" (Thu–Sun) segmentation is
/// derived later in PostHog at analysis time, not on-device.
enum DayOfWeek {

    private static let names = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
    ]

    static func label(for date: Date, calendar: Calendar = .current) -> String {
        // Calendar weekday: 1 = Sunday … 7 = Saturday.
        let weekday = calendar.component(.weekday, from: date)
        return names[(weekday - 1) % 7]
    }
}
