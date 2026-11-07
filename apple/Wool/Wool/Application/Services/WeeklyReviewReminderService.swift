import Foundation
import UserNotifications

final class WeeklyReviewReminderService {
    static let shared = WeeklyReviewReminderService()
    static let notificationIdentifier = "wool.weekly-review.reminder"
    static let deepLink = URL(string: "wool://weekly-review")!

    func schedule(
        weekday: Int = 2,
        hour: Int = 9,
        minute: Int = 0,
        center: any LocalNotificationCenter = UNUserNotificationCenter.current()
    ) {
        var date = DateComponents()
        date.weekday = weekday
        date.hour = hour
        date.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Weekly Review"
        content.body = "Close open loops and make space for the week ahead."
        content.sound = .default
        content.userInfo = ["type": "weekly_review", "deepLink": Self.deepLink.absoluteString]

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.add(request)
    }

    func cancel(center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
