import Foundation
import UserNotifications

/// Schedules and cancels local notifications for a `TaskItem`'s due date.
///
/// One pending notification per task is tracked with a stable, per-task
/// identifier (`wool.task-due.<taskID>`), so many tasks can each have
/// their own reminder independently of the single-slot focus-session
/// notification in `NotificationManager`.
final class TaskDueNotificationService {
    static let shared = TaskDueNotificationService()

    private static func identifier(for taskID: UUID) -> String {
        "wool.task-due.\(taskID.uuidString)"
    }

    /// Schedules (or replaces) a due-date reminder for `task`, or cancels any
    /// existing reminder if the task no longer qualifies for one (no due
    /// date, due date in the past, task completed/cancelled, or
    /// notifications disabled).
    func sync(task: TaskItem, center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        guard let dueDate = task.dueDate,
              dueDate > Date(),
              task.status != .completed,
              task.status != .cancelled,
              UserDefaults.standard.object(forKey: "notificationsEnabled") == nil
                || UserDefaults.standard.bool(forKey: "notificationsEnabled")
        else {
            cancel(taskID: task.id, center: center)
            return
        }
        schedule(taskID: task.id, title: task.title, dueDate: dueDate, center: center)
    }

    func schedule(taskID: UUID, title: String, dueDate: Date, center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        let content = UNMutableNotificationContent()
        content.title = "Wool"
        content.body = title.isEmpty ? "A task is due now." : "\"\(title)\" is due now."
        content.sound = .default
        content.userInfo = ["type": "task_due", "taskID": taskID.uuidString]

        let interval = max(1, dueDate.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: taskID),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: taskID)])
        center.add(request)
    }

    func cancel(taskID: UUID, center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: taskID)])
    }
}
