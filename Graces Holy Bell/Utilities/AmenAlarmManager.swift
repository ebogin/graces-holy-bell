import Foundation
import UserNotifications

/// Manages scheduling and cancellation of the Amen Alarm on the iPhone.
///
/// The Amen Alarm fires a silent local notification (phone vibrates, no sound)
/// at `lastPrayerTimestamp + alarmDuration`. It is rescheduled every time the
/// user slides PRAY, and cancelled when the session stops or is cleared.
///
/// All methods are safe to call from @MainActor context.
final class AmenAlarmManager {

    static let notificationID = "amenAlarm"
    private static let soundName = "silence.caf"

    // MARK: - Permission

    /// Requests UNUserNotification permission if not already granted.
    /// Call when the user first enables Phone or Watch toggle.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    // MARK: - Schedule / Cancel

    /// Schedules a phone Amen Alarm notification to fire at `fireDate`.
    ///
    /// Any previously scheduled alarm is replaced. If `fireDate` is in the
    /// past, no notification is scheduled (alarm already missed this interval).
    func scheduleAlarm(fireDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔔 Amen"
        // Silent notification: use a bundled silence.caf so the phone delivers
        // a haptic vibration without audible sound.
        content.sound = UNNotificationSound(named: UNNotificationSoundName(Self.soundName))

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// Cancels any pending Amen Alarm notification on this device.
    func cancelAlarm() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
