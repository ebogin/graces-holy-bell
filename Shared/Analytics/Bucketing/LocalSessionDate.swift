import Foundation

/// The user's LOCAL calendar date for a session-start timestamp, as an ISO
/// `yyyy-MM-dd` string (their own timezone, not UTC).
///
/// Sessions are attributed to the day they begin in the *user's* timezone: a
/// session that starts at 1am Saturday in the UK and one that starts at 5pm
/// Friday in California — the same UTC instant — log as `Saturday` and `Friday`
/// respectively. Mirrors the on-device local stamping already used for
/// `day_of_week` / `time_of_day_bucket`; computed from `Calendar.current`, which
/// carries the device's current timezone (so it follows the user when they
/// travel, and is immune to VPN/IP geolocation error).
enum LocalSessionDate {

    /// Zero-padded, locale-independent, lexically sortable `yyyy-MM-dd`.
    static func label(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
