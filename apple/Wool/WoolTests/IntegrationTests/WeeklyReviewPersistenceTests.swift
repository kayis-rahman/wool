import XCTest
import SwiftData
@testable import Wool

@MainActor
final class WeeklyReviewPersistenceTests: XCTestCase {
    func testProgressSurvivesContextSaveAndReload() throws {
        let marker = UUID().uuidString
        let configuration = ModelConfiguration(
            "WeeklyReviewTests-\(marker)",
            schema: WoolModelContainer.schema,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: WoolModelContainer.schema, configurations: configuration)
        let context = ModelContext(container)
        let service = WeeklyReviewService()
        let review = service.makeWeeklyReview()
        context.insert(review)
        service.saveStep(review, step: 0, skipped: false)
        try context.save()

        let reloaded = try context.fetch(FetchDescriptor<WeeklyReview>())
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.currentStep, 1)
        XCTAssertEqual(reloaded.first?.completedStepCount, 1)
    }

    func testSameWeekReviewIsReusedInsteadOfDuplicated() throws {
        let marker = UUID().uuidString
        let configuration = ModelConfiguration(
            "WeeklyReviewTests-\(marker)",
            schema: WoolModelContainer.schema,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: WoolModelContainer.schema, configurations: configuration)
        let context = ModelContext(container)
        let service = WeeklyReviewService()
        let now = Date()
        let review = service.makeWeeklyReview(now: now)
        context.insert(review)
        try context.save()

        XCTAssertEqual(service.review(forWeekContaining: now, from: [review])?.id, review.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WeeklyReview>()).count, 1)
    }

    func testStaleSnapshotRemovesCompletedTaskAfterReload() throws {
        let marker = UUID().uuidString
        let configuration = ModelConfiguration(
            "WeeklyReviewTests-\(marker)",
            schema: WoolModelContainer.schema,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: WoolModelContainer.schema, configurations: configuration)
        let context = ModelContext(container)
        let service = WeeklyReviewService()
        let task = TaskItem(title: "Stale \(marker)", status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        let review = service.makeWeeklyReview()
        context.insert(task)
        context.insert(review)
        service.prepareStaleItems([task], for: review)
        try context.save()

        task.status = .completed
        service.prepareStaleItems([task], for: review)
        try context.save()

        let persisted = try context.fetch(FetchDescriptor<WeeklyReview>())
        XCTAssertTrue(persisted.first?.staleTaskIDs.isEmpty == true)
    }
}
