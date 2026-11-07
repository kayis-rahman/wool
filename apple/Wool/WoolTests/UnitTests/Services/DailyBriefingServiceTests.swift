import XCTest
@testable import Wool

@MainActor
final class DailyBriefingServiceTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_735_776_000)

    func testDueTodayAndOverdueAreSeparate() {
        let today = TaskItem(title: "Ship update", status: .nextAction, dueDate: now.addingTimeInterval(3600))
        let overdue = TaskItem(title: "Send invoice", status: .nextAction, dueDate: now.addingTimeInterval(-86_400))
        let sections = DailyBriefingComposer.sections(from: [today, overdue], now: now, calendar: calendar)

        XCTAssertEqual(sections.dueToday.map(\.title), ["Ship update"])
        XCTAssertEqual(sections.overdue.map(\.title), ["Send invoice"])
    }

    func testNothingDueReportsWaitingCount() {
        let waiting = TaskItem(title: "Client reply", status: .waitingFor, dueDate: now.addingTimeInterval(-3600))
        let result = DailyBriefingResult(sections: DailyBriefingComposer.sections(from: [waiting], now: now, calendar: calendar), narrative: nil)
        XCTAssertEqual(result.plainText, "Nothing due today, 1 item in Waiting For.\nOverdue\n• Client reply\nCheck on this\n• Client reply")
    }

    func testNothingDueAndNothingWaitingIsPositive() {
        let result = DailyBriefingResult(sections: DailyBriefingComposer.sections(from: [], now: now, calendar: calendar), narrative: nil)
        XCTAssertEqual(result.plainText, "All clear — nothing is due today.")
    }

    func testWaitingForAndAllDayCalendarEventStayDistinct() {
        let waiting = TaskItem(title: "Check contract", status: .waitingFor, dueDate: now.addingTimeInterval(-1))
        let event = DailyBriefingEvent(id: "all-day", title: "Conference", startDate: now, endDate: now.addingTimeInterval(86_400), isAllDay: true)
        let sections = DailyBriefingComposer.sections(from: [waiting], now: now, calendar: calendar, calendarEvents: [event])

        XCTAssertEqual(sections.waiting.map(\.title), ["Check contract"])
        XCTAssertTrue(sections.dueToday.isEmpty)
        XCTAssertTrue(sections.calendarEvents.first?.isAllDay == true)
    }

    func testTimezoneBoundariesUseSuppliedCalendar() {
        var timezoneCalendar = calendar
        timezoneCalendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let task = TaskItem(title: "Local morning", status: .nextAction, dueDate: now.addingTimeInterval(3600))
        let sections = DailyBriefingComposer.sections(from: [task], now: now, calendar: timezoneCalendar)

        XCTAssertEqual(sections.dueToday.count, 1)
    }

    func testUpNextContainsOnlyUndatedNextActionsAndIsCappedAtFive() {
        let tasks = (0..<7).map { index in
            let task = TaskItem(title: "Action \(index)", status: .nextAction)
            task.sortOrder = Double(6 - index)
            return task
        } + [TaskItem(title: "Future action", status: .nextAction, dueDate: now.addingTimeInterval(86_400))]

        let sections = DailyBriefingComposer.sections(from: tasks, now: now, calendar: calendar)

        XCTAssertEqual(sections.upNext.count, 5)
        XCTAssertEqual(sections.upNext.map(\.title), ["Action 6", "Action 5", "Action 4", "Action 3", "Action 2"])
    }

    func testOverdueIncludesWaitingForButExcludesClosedTasks() {
        let overdueAction = TaskItem(title: "Overdue action", status: .nextAction, dueDate: now.addingTimeInterval(-86_400))
        let overdueWaiting = TaskItem(title: "Overdue waiting", status: .waitingFor, dueDate: now.addingTimeInterval(-86_400))
        let completed = TaskItem(title: "Completed", status: .completed, dueDate: now.addingTimeInterval(-86_400))
        let cancelled = TaskItem(title: "Cancelled", status: .cancelled, dueDate: now.addingTimeInterval(-86_400))

        let sections = DailyBriefingComposer.sections(from: [overdueAction, overdueWaiting, completed, cancelled], now: now, calendar: calendar)

        XCTAssertEqual(Set(sections.overdue.map(\.title)), Set(["Overdue action", "Overdue waiting"]))
        XCTAssertEqual(sections.waiting.map(\.title), ["Overdue waiting"])
    }

    func testMalformedCalendarEventsAreOmitted() {
        let valid = DailyBriefingEvent(id: "valid", title: "Planning", startDate: now, endDate: now.addingTimeInterval(3600), isAllDay: false)
        let reversed = DailyBriefingEvent(id: "reversed", title: "Broken", startDate: now.addingTimeInterval(3600), endDate: now, isAllDay: false)
        let blankTitle = DailyBriefingEvent(id: "blank", title: " \n", startDate: now, endDate: now, isAllDay: false)

        let sections = DailyBriefingComposer.sections(from: [], now: now, calendar: calendar, calendarEvents: [reversed, blankTitle, valid])

        XCTAssertEqual(sections.calendarEvents.map(\.id), ["valid"])
    }

    func testCalendarEventsAreScopedToTodayAndDuplicateIDsAreRemoved() {
        let today = DailyBriefingEvent(id: "today", title: "Today", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false)
        let duplicate = DailyBriefingEvent(id: "today", title: "Duplicate", startDate: now.addingTimeInterval(7200), endDate: now.addingTimeInterval(10_800), isAllDay: false)
        let tomorrow = DailyBriefingEvent(id: "tomorrow", title: "Tomorrow", startDate: now.addingTimeInterval(86_400), endDate: now.addingTimeInterval(90_000), isAllDay: false)

        let sections = DailyBriefingComposer.sections(from: [], now: now, calendar: calendar, calendarEvents: [tomorrow, duplicate, today])

        XCTAssertEqual(sections.calendarEvents.map(\.id), ["today"])
        XCTAssertEqual(sections.timedCalendarEvents.count, 1)
        XCTAssertTrue(sections.allDayCalendarEvents.isEmpty)
    }

    func testCalendarEventsSortAllDayBeforeTimedAtSameStart() {
        let timed = DailyBriefingEvent(id: "timed", title: "Timed", startDate: now, endDate: now.addingTimeInterval(3600), isAllDay: false)
        let allDay = DailyBriefingEvent(id: "all-day", title: "All day", startDate: now, endDate: now.addingTimeInterval(86_400), isAllDay: true)

        let sections = DailyBriefingComposer.sections(from: [], now: now, calendar: calendar, calendarEvents: [timed, allDay])

        XCTAssertEqual(sections.calendarEvents.map(\.id), ["all-day", "timed"])
    }

    func testNotDeterminedCalendarRequestsAccessBeforeFetchingEvents() async {
        let provider = RequestingCalendarProvider(event: DailyBriefingEvent(id: "event", title: "Planning", startDate: now, endDate: now.addingTimeInterval(3600), isAllDay: false))
        let service = DailyBriefingService(calendarProvider: provider, narrativeProvider: { _ in nil })

        let result = await service.makeBriefing(tasks: [], now: now)

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(result.sections.calendarEvents.map(\.id), ["event"])
    }

    func testCalendarFailureAndBlankAINarrativeFallBackToPlainResult() async {
        let service = DailyBriefingService(
            calendarProvider: ThrowingCalendarProvider(),
            narrativeProvider: { _ in " \n\t" }
        )
        let task = TaskItem(title: "Fallback action", status: .nextAction, dueDate: now)

        let result = await service.makeBriefing(tasks: [task], now: now)

        XCTAssertTrue(result.sections.calendarEvents.isEmpty)
        XCTAssertNil(result.narrative)
        XCTAssertTrue(result.plainText.contains("Fallback action"))
    }
}

@MainActor
private struct ThrowingCalendarProvider: DailyBriefingCalendarProvider {
    enum Failure: Error { case unavailable }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        throw Failure.unavailable
    }
}

@MainActor
private final class RequestingCalendarProvider: DailyBriefingCalendarProvider {
    let event: DailyBriefingEvent
    private(set) var requestCount = 0

    init(event: DailyBriefingEvent) {
        self.event = event
    }

    var authorization: DailyBriefingCalendarAuthorization { requestCount == 0 ? .notDetermined : .authorized }

    func requestAccessIfNeeded() async -> Bool {
        requestCount += 1
        return true
    }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        [event]
    }
}
