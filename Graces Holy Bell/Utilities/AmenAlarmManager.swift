import Foundation
import UserNotifications

/// Manages scheduling and cancellation of the Amen Alarm on the iPhone.
///
/// The Amen Alarm fires local notifications at `lastPrayerTimestamp +
/// alarmDuration`. It is rescheduled every time the user slides PRAY, and
/// cancelled when the session stops or is cleared.
///
/// Persistence (background delivery):
/// - Bell Sound ON: one notification carrying the ~29.5s clanging bell sound.
/// - Bell Sound OFF: a burst of four silent notifications (silence.caf gives a
///   haptic with no audible sound) spread across 30 seconds, so the vibration
///   repeats instead of buzzing once and vanishing.
///
/// All methods are safe to call from @MainActor context.
final class AmenAlarmManager {

    static let notificationID = "amenAlarm"
    private static let silentSoundName = "silence.caf"
    private static let bellSoundName = "bell_alarm.caf"

    /// Follow-up vibration pulses after the initial fire (seconds).
    private static let repeatOffsets: [TimeInterval] = [8, 16, 24]

    /// Every identifier this manager may have scheduled.
    private static var allIDs: [String] {
        [notificationID] + repeatOffsets.indices.map { "\(notificationID).repeat\($0)" }
    }

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

    /// Schedules the phone Amen Alarm to fire at `fireDate`.
    ///
    /// Any previously scheduled alarm is replaced. If `fireDate` is in the
    /// past, no notification is scheduled (alarm already missed this interval).
    func scheduleAlarm(fireDate: Date, soundEnabled: Bool = false) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.allIDs)

        guard fireDate > .now else { return }

        if soundEnabled {
            // One notification carrying the full clanging-bell alarm sound.
            add(id: Self.notificationID, fireDate: fireDate, sound: Self.bellSoundName, to: center)
        } else {
            // Silent haptic at the fire moment, then repeat pulses across 30s.
            // (Separate silent notifications would cut the bell audio short,
            // so the burst only runs in silent mode.)
            add(id: Self.notificationID, fireDate: fireDate, sound: Self.silentSoundName, to: center)
            for (index, offset) in Self.repeatOffsets.enumerated() {
                add(
                    id: "\(Self.notificationID).repeat\(index)",
                    fireDate: fireDate.addingTimeInterval(offset),
                    sound: Self.silentSoundName,
                    to: center
                )
            }
        }
    }

    /// Cancels any pending Amen Alarm notifications on this device.
    func cancelAlarm() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: Self.allIDs)
    }

    // MARK: - Private

    private func add(
        id: String,
        fireDate: Date,
        sound: String,
        to center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Amen"
        content.body = "Time to pray. Tap to ring the bell."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        // Break through Focus modes and appear prominently — the alarm is
        // explicitly user-scheduled. Requires the Time Sensitive Notifications
        // entitlement; harmlessly downgraded to .active without it.
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
