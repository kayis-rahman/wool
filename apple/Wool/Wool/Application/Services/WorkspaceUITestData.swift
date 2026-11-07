import Foundation
import SwiftData

/// Deterministic relationship data for the isolated `-ui-testing` store only.
@MainActor
enum WorkspaceUITestData {
    static func seedProjectsAndAreasIfRequested(in context: ModelContext) throws {
        let environment = ProcessInfo.processInfo.environment
        guard WoolModelContainer.isTestingProcess,
              environment["WOOL_UI_TEST_SEED_PROJECTS_AREAS"] == "1"
        else { return }

        let projectTitle = "UI Test Project"
        let existing = try context.fetch(
            FetchDescriptor<Project>(predicate: #Predicate { $0.title == projectTitle })
        )
        guard existing.isEmpty else { return }

        let project = Project(title: projectTitle, desiredOutcome: "A verified project relationship")
        let emptyProject = Project(title: "UI Test Empty Project", desiredOutcome: "An outcome without actions")
        let primaryArea = Area(name: "UI Test Area", notes: "The primary test responsibility")
        let otherArea = Area(name: "UI Test Other Area", notes: "Must not leak into the primary area")
        let nextAction = TaskItem(
            title: "UI Test Project Next Action",
            status: .nextAction,
            project: project,
            areas: [primaryArea]
        )
        let completedAction = TaskItem(
            title: "UI Test Project Completed Action",
            status: .completed,
            project: project,
            areas: [primaryArea]
        )
        let unrelatedAction = TaskItem(
            title: "UI Test Other Area Action",
            status: .nextAction,
            areas: [otherArea]
        )

        context.insert(project)
        context.insert(emptyProject)
        context.insert(primaryArea)
        context.insert(otherArea)
        context.insert(nextAction)
        context.insert(completedAction)
        context.insert(unrelatedAction)
        try context.save()
    }

    static func seedWeeklyReviewStaleItemIfRequested(in context: ModelContext) throws {
        let environment = ProcessInfo.processInfo.environment
        guard WoolModelContainer.isTestingProcess,
              environment["WOOL_UI_TEST_SEED_WEEKLY_REVIEW_STALE"] == "1"
        else { return }

        let title = "UI Test Stale Review Item"
        let existing = try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })
        )
        guard existing.isEmpty else { return }

        let task = TaskItem(title: title, status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        context.insert(task)
        try context.save()
    }

    static func seedDailyBriefingIfRequested(in context: ModelContext) throws {
        let environment = ProcessInfo.processInfo.environment
        guard WoolModelContainer.isTestingProcess,
              environment["WOOL_UI_TEST_SEED_DAILY_BRIEFING"] == "1"
        else { return }

        let waitingOnly = environment["WOOL_UI_TEST_DAILY_BRIEFING_WAITING_ONLY"] == "1"
        let titles = waitingOnly
            ? ["UI Test Briefing Waiting"]
            : ["UI Test Briefing Due Today", "UI Test Briefing Up Next", "UI Test Briefing Overdue Waiting"]
        let existing = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { task in
            task.title == "UI Test Briefing Due Today" ||
            task.title == "UI Test Briefing Up Next" ||
            task.title == "UI Test Briefing Overdue Waiting" ||
            task.title == "UI Test Briefing Waiting"
        }))
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now.addingTimeInterval(-86_400)
        if !waitingOnly {
            context.insert(TaskItem(title: titles[0], status: .nextAction, dueDate: .now))
            let upNext = TaskItem(title: titles[1], status: .nextAction)
            upNext.sortOrder = 1
            context.insert(upNext)
            context.insert(TaskItem(title: titles[2], status: .waitingFor, dueDate: yesterday))
        } else {
            context.insert(TaskItem(title: titles[0], status: .waitingFor))
        }
        try context.save()
    }

    static func seedGmailIfRequested(in context: ModelContext) throws {
        let environment = ProcessInfo.processInfo.environment
        guard WoolModelContainer.isTestingProcess,
              environment["WOOL_GMAIL_UI_TESTING"] == "1"
        else { return }

        let email = "ui-fixture@gmail.com"
        let existing = try context.fetch(FetchDescriptor<GmailAccountRecord>(predicate: #Predicate { $0.accountIdentifier == email }))
        guard existing.isEmpty else { return }

        context.insert(GmailAccountRecord(accountIdentifier: email, displayName: "UI Gmail Fixture"))
        try context.save()
    }
}
