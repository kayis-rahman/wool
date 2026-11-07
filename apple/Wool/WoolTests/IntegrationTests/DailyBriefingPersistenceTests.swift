import XCTest
import SwiftData
@testable import Wool

@MainActor
final class DailyBriefingPersistenceTests: XCTestCase {
    func testBriefingReadsPersistedTasksAndExcludesCompletedItems() throws {
        let marker = UUID().uuidString
        let now = Date()
        let due = TaskItem(title: "Persisted due \(marker)", status: .nextAction, dueDate: now)
        let completed = TaskItem(title: "Completed \(marker)", status: .completed, dueDate: now)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(due)
        context.insert(completed)
        try context.save()

        let persisted = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title.contains(marker) }))
        let sections = DailyBriefingComposer.sections(from: persisted, now: now)

        XCTAssertEqual(sections.dueToday.map(\.title), ["Persisted due \(marker)"])
        XCTAssertFalse(sections.dueToday.contains { $0.title.contains("Completed") })
    }

    func testBriefingUsesCurrentPersistedStatusAfterCompletion() throws {
        let marker = UUID().uuidString
        let task = TaskItem(title: "Complete me \(marker)", status: .nextAction, dueDate: .now)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(task)
        try context.save()

        task.status = .completed
        try context.save()

        let persisted = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == "Complete me \(marker)" }))
        XCTAssertTrue(DailyBriefingComposer.sections(from: persisted).dueToday.isEmpty)
    }

    func testOfflineBriefingUsesLocalStoreAndOmitsUnavailableCalendar() async throws {
        let marker = UUID().uuidString
        let task = TaskItem(title: "Offline action \(marker)", status: .nextAction, dueDate: .now)
        let service = DailyBriefingService(calendarProvider: EmptyDailyBriefingCalendarProvider())

        let result = await service.makeBriefing(tasks: [task])

        XCTAssertEqual(result.sections.dueToday.map(\.title), ["Offline action \(marker)"])
        XCTAssertTrue(result.sections.calendarEvents.isEmpty)
    }

    func testCalendarEventsAreTransientAndDoNotPersistWithTasks() async throws {
        let marker = UUID().uuidString
        let now = Date()
        let task = TaskItem(title: "Calendar context task \(marker)", status: .nextAction, dueDate: now)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(task)
        try context.save()

        let event = DailyBriefingEvent(
            id: "integration-calendar-\(marker)",
            title: "Planning context",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(7200),
            isAllDay: false
        )
        let service = DailyBriefingService(
            calendarProvider: IntegrationCalendarProvider(events: [event]),
            narrativeProvider: { _ in nil }
        )
        let result = await service.makeBriefing(tasks: [task], now: now)

        XCTAssertEqual(result.sections.calendarEvents.map(\.id), [event.id])
        let persisted = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title.contains(marker) }))
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.title, task.title)
    }

    func testCalendarFailurePreservesPersistedTaskBriefing() async throws {
        let marker = UUID().uuidString
        let now = Date()
        let task = TaskItem(title: "Calendar failure task \(marker)", status: .nextAction, dueDate: now)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(task)
        try context.save()

        let service = DailyBriefingService(
            calendarProvider: FailingCalendarProvider(),
            narrativeProvider: { _ in nil }
        )
        let result = await service.makeBriefing(tasks: [task], now: now)

        XCTAssertEqual(result.sections.dueToday.map(\.title), [task.title])
        XCTAssertTrue(result.sections.calendarEvents.isEmpty)
        let persisted = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title.contains(marker) }))
        XCTAssertEqual(persisted.count, 1)
    }

    func testPersistedUndatedAndOverdueWaitingTasksAppearInTheirSections() throws {
        let marker = UUID().uuidString
        let upNext = TaskItem(title: "Up next \(marker)", status: .nextAction)
        let overdueWaiting = TaskItem(title: "Overdue waiting \(marker)", status: .waitingFor, dueDate: Date(timeIntervalSinceNow: -2 * 86_400))
        let completed = TaskItem(title: "Closed \(marker)", status: .completed)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(upNext)
        context.insert(overdueWaiting)
        context.insert(completed)
        try context.save()

        let persisted = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title.contains(marker) }))
        let sections = DailyBriefingComposer.sections(from: persisted)

        XCTAssertEqual(sections.upNext.map(\.title), ["Up next \(marker)"])
        XCTAssertEqual(sections.overdue.map(\.title), ["Overdue waiting \(marker)"])
        XCTAssertEqual(sections.waiting.map(\.title), ["Overdue waiting \(marker)"])
    }

    func testProductionStoreRemainsConfiguredForPrivateCloudKitSync() {
        let configuration = WoolModelContainer.configuration(isTesting: false)
        XCTAssertEqual(configuration.cloudKitContainerIdentifier, WoolModelContainer.cloudKitContainerIdentifier)
    }
}

@MainActor
private struct IntegrationCalendarProvider: DailyBriefingCalendarProvider {
    let events: [DailyBriefingEvent]

    var authorization: DailyBriefingCalendarAuthorization { .authorized }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        events
    }
}

@MainActor
private struct FailingCalendarProvider: DailyBriefingCalendarProvider {
    enum Failure: Error { case unavailable }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        throw Failure.unavailable
    }
}
