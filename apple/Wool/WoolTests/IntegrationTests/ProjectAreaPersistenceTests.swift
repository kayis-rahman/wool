import XCTest
import SwiftData

@testable import Wool

@MainActor
final class ProjectAreaPersistenceTests: XCTestCase {
    func testProjectAndAreaRelationshipsPersistWithCorrectProgressAndScopedOpenTasks() throws {
        let marker = UUID().uuidString
        let project = Project(title: "Launch (marker)", desiredOutcome: "A released product")
        let work = Area(name: "Work (marker)")
        let personal = Area(name: "Personal (marker)")
        let next = TaskItem(title: "Publish (marker)", status: .nextAction, project: project, areas: [work])
        let complete = TaskItem(title: "Approve (marker)", status: .completed, project: project, areas: [work])
        let unrelated = TaskItem(title: "Buy (marker)", status: .nextAction, areas: [personal])
        let context = ModelContext(WoolModelContainer.shared)

        context.insert(project)
        context.insert(work)
        context.insert(personal)
        context.insert(next)
        context.insert(complete)
        context.insert(unrelated)
        try context.save()

        let projectTitle = project.title
        let workName = work.name
        let fetchedProject = try XCTUnwrap(
            context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.title == projectTitle })).first
        )
        let fetchedWork = try XCTUnwrap(
            context.fetch(FetchDescriptor<Area>(predicate: #Predicate { $0.name == workName })).first
        )
        let fetchedTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let projectTasks = fetchedTasks.filter { $0.project?.id == fetchedProject.id }

        let persistedProjectTaskIDs = projectTasks.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let expectedProjectTaskIDs = [next.id, complete.id].sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual(persistedProjectTaskIDs, expectedProjectTaskIDs)
        XCTAssertEqual(WorkspaceMetrics.projectMetrics(tasks: projectTasks), ProjectMetrics(total: 2, completed: 1))
        XCTAssertEqual(WorkspaceMetrics.openTasks(in: fetchedWork, from: fetchedTasks).map(\.id), [next.id])
        XCTAssertFalse(WorkspaceMetrics.openTasks(in: fetchedWork, from: fetchedTasks).contains { $0.id == unrelated.id })

        fetchedProject.status = .completed
        try context.save()
        XCTAssertEqual(fetchedProject.status, .completed)
        XCTAssertNotNil(fetchedProject.completedAt)
    }

    func testArchivedProjectAndLinkedTasksPersistTogetherAndRestore() throws {
        let marker = UUID().uuidString
        let project = Project(title: "Archive project \(marker)", desiredOutcome: "Preserve the outcome")
        let next = TaskItem(title: "Archive next action \(marker)", status: .nextAction, project: project)
        let completed = TaskItem(title: "Archive completed action \(marker)", status: .completed, project: project)
        let context = ModelContext(WoolModelContainer.shared)

        context.insert(project)
        context.insert(next)
        context.insert(completed)
        project.archive(at: Date(timeIntervalSince1970: 500))
        try context.save()

        let projectID = project.id
        let fetchedProject = try XCTUnwrap(
            context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectID })).first
        )
        let fetchedTasks = try context.fetch(FetchDescriptor<TaskItem>())
            .filter { $0.project?.id == projectID }

        XCTAssertTrue(fetchedProject.isArchived)
        XCTAssertEqual(fetchedTasks.map(\.id).sorted { $0.uuidString < $1.uuidString }, [next.id, completed.id].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(fetchedTasks.first { $0.id == next.id }?.status, .nextAction)
        XCTAssertEqual(fetchedTasks.first { $0.id == completed.id }?.status, .completed)

        fetchedProject.restore(at: Date(timeIntervalSince1970: 600))
        try context.save()

        XCTAssertFalse(fetchedProject.isArchived)
        XCTAssertEqual(fetchedProject.status, .active)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TaskItem>()).contains { $0.project?.id == projectID && $0.id == next.id })
    }

    func testDeletingAreaUnlinksAllTasksButPreservesOtherAreas() throws {
        let marker = UUID().uuidString
        let work = Area(name: "Work \(marker)")
        let health = Area(name: "Health \(marker)")
        let task = TaskItem(title: "Shared task \(marker)", areas: [work, health])
        let context = ModelContext(WoolModelContainer.shared)

        context.insert(work)
        context.insert(health)
        context.insert(task)
        try context.save()

        task.areas = task.areas?.filter { $0.id != work.id }
        context.delete(work)
        try context.save()

        XCTAssertEqual(task.areas?.map(\.id), [health.id])
        XCTAssertFalse(try context.fetch(FetchDescriptor<Area>()).contains { $0.id == work.id })
    }
}
