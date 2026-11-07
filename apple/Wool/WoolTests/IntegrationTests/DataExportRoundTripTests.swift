import XCTest
import SwiftData
@testable import Wool

@MainActor
final class DataExportRoundTripTests: XCTestCase {
    func testExportRestoreRoundTripPreservesData() throws {
        let marker = UUID().uuidString
        let configuration = ModelConfiguration(
            "DataExportRoundTripTests-\(marker)",
            schema: WoolModelContainer.schema,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: WoolModelContainer.schema, configurations: configuration)
        let context = ModelContext(container)

        // Seed data
        let area = Area(name: "Work")
        let project = Project(title: "Ship export", desiredOutcome: "Done", notes: "n")
        context.insert(area)
        context.insert(project)

        let task = TaskItem(title: "Write exporter", notes: "details", status: .nextAction, dueDate: Date(timeIntervalSince1970: 1_700_000_000), contextTags: ["a", "b"], project: project, areas: [area])
        context.insert(task)

        let review = WeeklyReview(weekStart: Date(timeIntervalSince1970: 1_699_000_000), weekEnd: Date(timeIntervalSince1970: 1_699_604_800))
        context.insert(review)
        let item = WeeklyReviewItem(title: "Collect", instructions: "do", kind: .collect, sortOrder: 1)
        item.review = review
        context.insert(item)
        try context.save()

        let areaId = area.id
        let projectId = project.id
        let taskId = task.id
        let reviewId = review.id
        let itemId = item.id

        // Export
        let data = try DataExportService.exportJSON(in: context)

        // Wipe
        try context.delete(model: WeeklyReviewItem.self)
        try context.delete(model: WeeklyReview.self)
        try context.delete(model: TaskItem.self)
        try context.delete(model: Project.self)
        try context.delete(model: Area.self)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty)

        // Restore
        try DataExportService.restore(from: data, in: context)

        let restoredAreas = try context.fetch(FetchDescriptor<Area>())
        let restoredProjects = try context.fetch(FetchDescriptor<Project>())
        let restoredTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let restoredReviews = try context.fetch(FetchDescriptor<WeeklyReview>())
        let restoredItems = try context.fetch(FetchDescriptor<WeeklyReviewItem>())

        XCTAssertEqual(restoredAreas.count, 1)
        XCTAssertEqual(restoredProjects.count, 1)
        XCTAssertEqual(restoredTasks.count, 1)
        XCTAssertEqual(restoredReviews.count, 1)
        XCTAssertEqual(restoredItems.count, 1)

        XCTAssertEqual(restoredAreas.first?.id, areaId)
        XCTAssertEqual(restoredProjects.first?.id, projectId)
        XCTAssertEqual(restoredTasks.first?.id, taskId)
        XCTAssertEqual(restoredReviews.first?.id, reviewId)
        XCTAssertEqual(restoredItems.first?.id, itemId)
        XCTAssertEqual(restoredTasks.first?.project?.id, projectId)
        XCTAssertEqual(restoredTasks.first?.areas?.first?.id, areaId)
    }
}
