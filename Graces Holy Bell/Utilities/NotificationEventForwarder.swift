import Foundation
import UserNotifications

/// Bridges Amen Alarm notification taps into analytics.
///
/// Implements **only** `didReceive(response:)` — `willPresent` is intentionally
/// left unimplemented so the app's existing foreground-presentation behavior is
/// unchanged (analytics must not alter behavior). Only taps on the Amen Alarm
/// notification are forwarded.
final class NotificationEventForwarder: NSObject, UNUserNotificationCenterDelegate {

    private let onAmenAlarmTapped: () -> Void

    init(onAmenAlarmTapped: @escaping () -> Void) {
        self.onAmenAlarmTapped = onAmenAlarmTapped
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Prefix match covers the follow-up ".repeatN" burst notifications too.
        if response.notification.request.identifier.hasPrefix(AmenAlarmManager.notificationID) {
            onAmenAlarmTapped()
        }
        completionHandler()
    }
}
