import XCTest
import UserNotifications
@testable import Wool

@MainActor
final class NotificationSchedulingTests: XCTestCase {
    private var center: RecordingNotificationCenter!

    override func setUp() {
        super.setUp()
        center = RecordingNotificationCenter()
        UserDefaults.standard.removeObject(forKey: "notificationsEnabled")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "notificationsEnabled")
        center = nil
        super.tearDown()
    }

    func testInboxAgingSchedulesReminderForStaleInboxItem() {
        let now = Date(timeIntervalSince1970: 100_000)
        let stale = TaskItem(title: "Call the dentist", status: .inbox)
        stale.createdAt = now.addingTimeInterval(-25 * 60 * 60)

        InboxAgingReminderService.shared.checkAndScheduleIfNeeded(
            inboxTasks: [stale], now: now, center: center
        )

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, InboxAgingReminderService.notificationIdentifier)
        XCTAssertEqual(center.addedRequests.first?.content.title, "Inbox Needs Attention")
        XCTAssertEqual(center.addedRequests.first?.content.userInfo["deepLink"] as? String, "wool://inbox")
    }

    func testInboxAgingCancelsWhenNothingIsStale() {
        let now = Date(timeIntervalSince1970: 100_000)
        let recent = TaskItem(title: "Recent", status: .inbox)
        recent.createdAt = now.addingTimeInterval(-60)

        InboxAgingReminderService.shared.checkAndScheduleIfNeeded(
            inboxTasks: [recent], now: now, center: center
        )

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, [InboxAgingReminderService.notificationIdentifier])
    }

    func testTaskDueNotificationSchedulesFutureOpenTask() {
        let task = TaskItem(title: "Submit expenses", status: .nextAction)
        task.dueDate = Date().addingTimeInterval(3_600)

        TaskDueNotificationService.shared.sync(task: task, center: center)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertTrue(center.addedRequests[0].identifier.contains(task.id.uuidString))
        XCTAssertEqual(center.addedRequests[0].content.body, "\"Submit expenses\" is due now.")
    }

    func testTaskDueNotificationCancelsCompletedTask() {
        let task = TaskItem(title: "Already done", status: .completed)
        task.dueDate = Date().addingTimeInterval(3_600)

        TaskDueNotificationService.shared.sync(task: task, center: center)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.removedIdentifiers.count, 1)
    }

    func testWeeklyReviewReminderSchedulesOneRequest() {
        WeeklyReviewReminderService.shared.schedule(center: center)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, WeeklyReviewReminderService.notificationIdentifier)
        XCTAssertFalse(center.addedRequests.first?.trigger is UNTimeIntervalNotificationTrigger)
    }

    func testWeeklyReviewReminderReplacesInsteadOfDuplicates() {
        WeeklyReviewReminderService.shared.schedule(center: center)
        WeeklyReviewReminderService.shared.schedule(center: center)

        XCTAssertEqual(center.addedRequests.count, 2)
        XCTAssertEqual(center.removedIdentifiers.filter { $0 == WeeklyReviewReminderService.notificationIdentifier }.count, 2)
    }

    func testWeeklyReviewReminderCancels() {
        WeeklyReviewReminderService.shared.cancel(center: center)

        XCTAssertEqual(center.removedIdentifiers, [WeeklyReviewReminderService.notificationIdentifier])
    }

    func testDailyBriefingReminderSchedulesAndCancels() {
        DailyBriefingReminderService.shared.schedule(center: center)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, DailyBriefingReminderService.notificationIdentifier)

        DailyBriefingReminderService.shared.cancel(center: center)
        XCTAssertEqual(center.removedIdentifiers.last, DailyBriefingReminderService.notificationIdentifier)
    }

}

private final class RecordingNotificationCenter: LocalNotificationCenter {
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func add(_ request: UNNotificationRequest) {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
