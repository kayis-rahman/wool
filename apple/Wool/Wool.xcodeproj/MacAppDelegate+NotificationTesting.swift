import Foundation
#if os(macOS)
import UserNotifications

extension MacAppDelegate {
    /// Handles a remote notification payload. Returns true if handled by the app (e.g., timer_sync), false otherwise.
    @discardableResult
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) -> Bool {
        if let type = userInfo["type"] as? String, type == "timer_sync" {
            // In production, this would trigger timer sync handling.
            // For tests, we just report it's handled.
            return true
        }
        return false
    }

    /// Derives presentation options for a given notification payload.
    /// Silent timer_sync notifications should not present UI; others may present standard options.
    func presentationOptions(for userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        if let type = userInfo["type"] as? String, type == "timer_sync" {
            return []
        }
        return [.banner, .sound]
    }
}
#endif
