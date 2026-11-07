import Foundation
import UserNotifications

/// Nudges the user when Inbox items have gone untriaged for too long — a
/// classic GTD hygiene reminder. Checked opportunistically (e.g. when the
/// Inbox tab appears) rather than via a background task scheduler.
@MainActor
final class InboxAgingReminderService {
    static let shared = InboxAgingReminderService()

    static let notificationIdentifier = "wool.inbox-aging.reminder"
    static let deepLink = URL(string: "wool://inbox")!

    /// How long an item may sit untriaged in the Inbox before we nudge.
    static let stalenessThreshold: TimeInterval = 24 * 60 * 60

    /// Short delay before firing, so this behaves like a local "soon" reminder
    /// rather than an immediate interruption when the app is foregrounded.
    static let notificationDelay: TimeInterval = 60 * 60

    private init() {}

    /// Checks the given inbox tasks and schedules or cancels the aging
    /// reminder as appropriate. Defaults `notificationsEnabled` to true when
    /// the key is absent (the setting may not have been persisted yet).
    func checkAndScheduleIfNeeded(
        inboxTasks: [TaskItem],
        now: Date = Date(),
        center: any LocalNotificationCenter = UNUserNotificationCenter.current()
    ) {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "notificationsEnabled")

        let staleTasks = inboxTasks.filter { task in
            task.status == .inbox && now.timeIntervalSince(task.createdAt) >= Self.stalenessThreshold
        }

        guard notificationsEnabled, !staleTasks.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Inbox Needs Attention"
        content.body = staleTasks.count == 1
            ? "1 capture has been waiting over a day. Take a moment to process it."
            : "\(staleTasks.count) captures have been waiting over a day. Take a moment to process them."
        content.sound = .default
        content.userInfo = ["type": "inbox_aging", "deepLink": Self.deepLink.absoluteString]

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.notificationDelay, repeats: false)
        )

        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.add(request)
    }

    func cancel(center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
