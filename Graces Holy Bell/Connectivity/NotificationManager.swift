import Foundation
import UserNotifications

/// Manages local notification scheduling for the suggested prayer interval on iPhone.
///
/// Schedules a single "Time to Pray" notification that fires at
/// `lastPrayerTimestamp + intervalSeconds`. Rescheduled on every prayer logged,
/// cancelled when the session stops.
///
/// Only used when the user has chosen "Notify on iPhone" in Settings.
/// When "Notify on Watch" is selected, the Watch schedules its own notification.
final class NotificationManager {

    static let shared = NotificationManager()

    private let notificationID = "prayReminder"

    private init() {}

    // MARK: - Permissions

    /// Requests notification authorization. Called once at app launch.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Scheduling

    /// Schedules a "Time to Pray" notification to fire at the given date.
    /// Cancels any existing pending notification before scheduling the new one.
    func schedule(fireAt date: Date) {
        cancel()

        let secondsUntilFire = date.timeIntervalSinceNow
        guard secondsUntilFire > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Pray"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilFire,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels any pending "Time to Pray" notification.
    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID]
        )
    }
}
