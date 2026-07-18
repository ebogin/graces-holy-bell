import Foundation
import UserNotifications

/// Routes Amen Alarm notification taps into the app (analytics + opening the
/// AMEN takeover).
///
/// Implements **only** `didReceive(response:)` — `willPresent` is intentionally
/// left unimplemented so the app's existing foreground-presentation behavior is
/// unchanged. Only taps on the Amen Alarm notification are forwarded.
///
/// Created (and installed as the notification-center delegate) in App.init so
/// a cold launch from a notification tap is never missed — the tap is buffered
/// until ContentView assigns `onAmenAlarmTapped` during setup.
final class NotificationEventForwarder: NSObject, UNUserNotificationCenterDelegate {

    /// Assigned by ContentView once the ViewModel/analytics exist. Assigning it
    /// flushes a tap that arrived earlier (cold launch straight from the tap).
    var onAmenAlarmTapped: (() -> Void)? {
        didSet {
            if hasPendingTap, let onAmenAlarmTapped {
                hasPendingTap = false
                onAmenAlarmTapped()
            }
        }
    }

    private var hasPendingTap = false

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Prefix match covers the follow-up ".repeatN" burst notifications too.
        if response.notification.request.identifier.hasPrefix(AmenAlarmManager.notificationID) {
            DispatchQueue.main.async { [self] in
                if let onAmenAlarmTapped {
                    onAmenAlarmTapped()
                } else {
                    hasPendingTap = true
                }
            }
        }
        completionHandler()
    }
}
