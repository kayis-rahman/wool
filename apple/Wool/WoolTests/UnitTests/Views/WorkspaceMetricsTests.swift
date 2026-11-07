import XCTest
@testable import Wool

@MainActor
final class WorkspaceMetricsTests: XCTestCase {
    func testProjectFilterSeparatesActiveAndCompletedOutcomes() {
        let active = Project(title: "Current project")
        let completed = Project(title: "Finished project")
        completed.status = .completed
        let archived = Project(title: "Archived project")
        archived.archive()

        XCTAssertEqual(WorkspaceMetrics.projects([active, completed, archived], matching: .active).map(\.title), ["Current project"])
        XCTAssertEqual(WorkspaceMetrics.projects([active, completed, archived], matching: .completed).map(\.title), ["Finished project"])
        XCTAssertEqual(WorkspaceMetrics.projects([active, completed, archived], matching: .archived).map(\.title), ["Archived project"])
    }

    func testProjectMetricsCalculateProgressAndRemainingActions() {
        let project = Project(title: "Launch website")
        let done = TaskItem(title: "Approve copy", status: .completed, project: project)
        let next = TaskItem(title: "Publish build", status: .nextAction, project: project)

        let metrics = WorkspaceMetrics.projectMetrics(tasks: [done, next])

        XCTAssertEqual(metrics, ProjectMetrics(total: 2, completed: 1))
        XCTAssertEqual(metrics.progress, 0.5)
        XCTAssertEqual(metrics.remaining, 1)
    }

    func testProjectMetricsWithNoActionsHasZeroProgress() {
        let metrics = WorkspaceMetrics.projectMetrics(tasks: [])

        XCTAssertEqual(metrics, ProjectMetrics(total: 0, completed: 0))
        XCTAssertEqual(metrics.progress, 0)
        XCTAssertEqual(metrics.remaining, 0)
    }

    func testProjectPortfolioSummarySeparatesMovingAndStalledActiveOutcomes() {
        let moving = Project(title: "Moving")
        let stalled = Project(title: "Needs action")
        let completed = Project(title: "Complete")
        completed.status = .completed
        let archived = Project(title: "Archived")
        archived.archive()
        let nextAction = TaskItem(title: "Ship it", status: .nextAction, project: moving)
        let completedAction = TaskItem(title: "Already done", status: .completed, project: stalled)

        let summary = WorkspaceMetrics.projectPortfolioSummary(
            projects: [moving, stalled, completed, archived],
            tasks: [nextAction, completedAction]
        )

        XCTAssertEqual(summary, ProjectPortfolioSummary(active: 2, moving: 1, needsNextAction: 1))
    }

    func testAreaTasksOnlyIncludesTasksLinkedToThatArea() {
        let work = Area(name: "Work")
        let personal = Area(name: "Personal")
        let workTask = TaskItem(title: "Prepare brief", areas: [work])
        let personalTask = TaskItem(title: "Book dentist", areas: [personal])
        let unassigned = TaskItem(title: "Clarify note")

        let result = WorkspaceMetrics.tasks(in: work, from: [workTask, personalTask, unassigned])

        XCTAssertEqual(result.map(\.title), ["Prepare brief"])
    }

    func testAreaFiltersIncludeAllAndUncategorizedWithoutHidingTasks() {
        let work = Area(name: "Work")
        let assigned = TaskItem(title: "Prepare brief", areas: [work])
        let uncategorized = TaskItem(title: "Clarify note")

        XCTAssertEqual(
            WorkspaceMetrics.tasks(matching: .all, areas: [work], from: [assigned, uncategorized]).map(\.title),
            ["Prepare brief", "Clarify note"]
        )
        XCTAssertEqual(
            WorkspaceMetrics.tasks(matching: .uncategorized, areas: [work], from: [assigned, uncategorized]).map(\.title),
            ["Clarify note"]
        )
    }

    func testAreaFilterMatchesAnyAreaAndDoesNotTrustStaleAreaTags() {
        let work = Area(name: "Work")
        let health = Area(name: "Health")
        let multiArea = TaskItem(title: "Plan appointment", areas: [work, health])
        let staleTagOnly = TaskItem(title: "Old area tag", contextTags: ["area:Work"])

        XCTAssertEqual(
            WorkspaceMetrics.tasks(matching: .area(work.id), areas: [work, health], from: [multiArea, staleTagOnly]).map(\.title),
            ["Plan appointment"]
        )
        XCTAssertEqual(
            WorkspaceMetrics.tasks(matching: .uncategorized, areas: [work, health], from: [multiArea, staleTagOnly]).map(\.title),
            ["Old area tag"]
        )
    }

    func testDeletedAreaFilterReturnsNoTasksAndItemsBecomeUncategorizedAfterUnlinking() {
        let work = Area(name: "Work")
        let task = TaskItem(title: "Prepare brief", areas: [work])
        task.areas = task.areas?.filter { $0.id != work.id }

        XCTAssertTrue(WorkspaceMetrics.tasks(matching: .area(work.id), areas: [], from: [task]).isEmpty)
        XCTAssertEqual(WorkspaceMetrics.tasks(matching: .uncategorized, areas: [], from: [task]).count, 1)
    }

    func testAreaNameValidationTrimsAndRejectsCaseInsensitiveDuplicates() {
        let existing = Area(name: " Work ")

        XCTAssertEqual(AreaNaming.normalized("  WORK\n"), AreaNaming.normalized(existing.name))
        XCTAssertEqual(AreaNaming.validate("work", against: [existing]), .duplicate)
        XCTAssertEqual(AreaNaming.validate("   ", against: [existing]), .empty)
        XCTAssertNil(AreaNaming.validate("Health", against: [existing]))
    }

    func testOpenAreaTasksExcludeCompletedCancelledAndOtherAreaActions() {
        let work = Area(name: "Work")
        let personal = Area(name: "Personal")
        let next = TaskItem(title: "Prepare brief", status: .nextAction, areas: [work])
        let completed = TaskItem(title: "Send invoice", status: .completed, areas: [work])
        let cancelled = TaskItem(title: "Old request", status: .cancelled, areas: [work])
        let otherArea = TaskItem(title: "Buy groceries", status: .nextAction, areas: [personal])

        let result = WorkspaceMetrics.openTasks(in: work, from: [next, completed, cancelled, otherArea])

        XCTAssertEqual(result.map(\.id), [next.id])
    }

    func testProjectFilterHidesCancelledOutcomesFromActiveAndCompletedLists() {
        let active = Project(title: "Current")
        let completed = Project(title: "Finished")
        completed.status = .completed
        let cancelled = Project(title: "No longer needed")
        cancelled.status = .cancelled

        XCTAssertEqual(WorkspaceMetrics.projects([active, completed, cancelled], matching: .active).map(\.id), [active.id])
        XCTAssertEqual(WorkspaceMetrics.projects([active, completed, cancelled], matching: .completed).map(\.id), [completed.id])
    }

    func testArchivingPreservesActiveStatusAndRestoringReturnsProjectToActive() {
        let project = Project(title: "Set aside project")
        let archivedAt = Date(timeIntervalSince1970: 100)

        project.archive(at: archivedAt)

        XCTAssertTrue(project.isArchived)
        XCTAssertEqual(project.status, .active)
        XCTAssertEqual(project.updatedAt, archivedAt)

        project.restore(at: Date(timeIntervalSince1970: 200))

        XCTAssertFalse(project.isArchived)
        XCTAssertEqual(project.status, .active)
        XCTAssertNil(project.statusBeforeArchiveRawValue)
    }

    func testArchivingAndRestoringCompletedProjectPreservesCompletionState() {
        let project = Project(title: "Finished project")
        project.status = .completed
        let completedAt = project.completedAt

        project.archive()
        project.restore()

        XCTAssertEqual(project.status, .completed)
        XCTAssertEqual(project.completedAt, completedAt)
    }

    func testArchivingAlreadyArchivedProjectDoesNotOverwriteOriginalStatus() {
        let project = Project(title: "Pause project")
        project.status = .completed
        project.archive()
        let archivedAt = project.updatedAt

        project.statusRawValue = ProjectStatus.active.rawValue
        project.archive(at: Date(timeIntervalSince1970: 300))
        project.restore()

        XCTAssertEqual(project.status, .completed)
        XCTAssertTrue(project.updatedAt >= archivedAt)
    }

    func testProjectCompletionStateTracksCompletionDate() {
        let project = Project(title: "Ship release")

        project.status = .completed

        XCTAssertEqual(project.status, .completed)
        XCTAssertNotNil(project.completedAt)
        XCTAssertEqual(project.statusRawValue, ProjectStatus.completed.rawValue)

        project.status = .active
        XCTAssertNil(project.completedAt)
    }
}
