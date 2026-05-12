import WatchKit
import SwiftUI
import UserNotifications

/// Hosts the custom full-screen notification interface for the "PRAY_REMINDER" category.
///
/// Registered with WKNotificationScene in Graces_Holy_Bell_Watch_AppApp.
/// Presented by watchOS when a "PRAY_REMINDER" local notification fires.
class NotificationController: WKUserNotificationHostingController<NotificationView> {

    override var body: NotificationView {
        NotificationView()
    }

    override func didReceive(_ notification: UNNotification) {
        // No additional data needed — the view is self-contained
    }
}
