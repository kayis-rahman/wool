import XCTest
import SwiftData

#if canImport(AppIntents)
import AppIntents
#endif

@testable import Wool

#if canImport(AppIntents)
@MainActor
final class CaptureIntentBehaviorTests: XCTestCase {
    func testAddCaptureIntentPersistsTheSameClassificationAsSharedService() async throws {
        let text = "Email the client tomorrow about the work plan"
        let expected = CaptureService(allowsFoundationModel: false).processInboxCapture(text: text)

        var intent = AddCaptureIntent()
        intent.title = text
        _ = try await intent.perform()

        let context = ModelContext(WoolModelContainer.shared)
        let items = try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\TaskItem.createdAt, order: .reverse)]))
        let persisted = try XCTUnwrap(items.first { $0.title == expected.title })

        XCTAssertEqual(persisted.title, expected.title)
        XCTAssertEqual(persisted.notes, expected.notes)
        XCTAssertEqual(persisted.status, expected.status)
        XCTAssertEqual(persisted.contextTags, expected.contextTags)
        let persistedDueDate = try XCTUnwrap(persisted.dueDate)
        let expectedDueDate = try XCTUnwrap(expected.dueDate)
        XCTAssertTrue(Calendar.current.isDate(persistedDueDate, inSameDayAs: expectedDueDate))
    }

    func testInAppEquivalentAndIntentCapturesPersistTheSameStructuredItem() async throws {
        let text = "Email the project lead tomorrow about the launch plan \(UUID().uuidString)"
        let inAppItem = CaptureService(allowsFoundationModel: false).processInboxCapture(text: text)
        let context = ModelContext(WoolModelContainer.shared)
        try CapturePersistenceService.save(inAppItem, in: context)

        var intent = AddCaptureIntent()
        intent.title = text
        _ = try await intent.perform()

        let savedItems = try context.fetch(
            FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.title == text },
                sortBy: [SortDescriptor(\TaskItem.createdAt)]
            )
        )
        XCTAssertEqual(savedItems.count, 2)

        let intentItem = try XCTUnwrap(savedItems.first { $0.id != inAppItem.id })
        XCTAssertEqual(intentItem.title, inAppItem.title)
        XCTAssertEqual(intentItem.notes, inAppItem.notes)
        XCTAssertEqual(intentItem.status, inAppItem.status)
        XCTAssertEqual(intentItem.contextTags, inAppItem.contextTags)
        XCTAssertEqual(intentItem.project?.id, inAppItem.project?.id)
        XCTAssertEqual(intentItem.areas?.map(\.id) ?? [], inAppItem.areas?.map(\.id) ?? [])
        let intentDueDate = try XCTUnwrap(intentItem.dueDate)
        let inAppDueDate = try XCTUnwrap(inAppItem.dueDate)
        XCTAssertTrue(Calendar.current.isDate(intentDueDate, inSameDayAs: inAppDueDate))
    }

    func testDuplicateCapturesArePersistedAsDistinctItems() throws {
        let text = "Capture this twice (UUID().uuidString)"
        let service = CaptureService(allowsFoundationModel: false)
        let first = service.processInboxCapture(text: text)
        let second = service.processInboxCapture(text: text)
        let context = ModelContext(WoolModelContainer.shared)

        try CapturePersistenceService.save(first, in: context)
        try CapturePersistenceService.save(second, in: context)

        let savedItems = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == text }))
        XCTAssertEqual(savedItems.count, 2)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(savedItems.allSatisfy { $0.status == .inbox })
    }

    func testMisheardCaptureIsPreservedAsRawInboxText() async throws {
        let text = "add by silk to Wool (UUID().uuidString)"
        var intent = AddCaptureIntent()
        intent.title = text
        _ = try await intent.perform()

        let context = ModelContext(WoolModelContainer.shared)
        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == text }))
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.status, .inbox)
    }

    func testCompleteTaskUsesFuzzyTitleMatchWithoutCreatingMissingTasks() throws {
        let task = TaskItem(title: "Buy milk (UUID().uuidString)", status: .nextAction)
        let other = TaskItem(title: "Book dentist", status: .nextAction)
        XCTAssertEqual(WoolIntentSupport.bestTaskMatch(for: "buy silk", in: [task, other])?.id, task.id)
        XCTAssertNil(WoolIntentSupport.bestTaskMatch(for: "something completely unrelated", in: [task, other]))
    }

    func testCompleteTaskRejectsWordOnlyMatches() throws {
        let marker = UUID().uuidString
        let task = TaskItem(title: "buy milk groceries \(marker)", status: .nextAction)
        let unrelated = TaskItem(title: "Calendar context task \(UUID().uuidString)", status: .nextAction)
        // A query sharing only the generic word "task" must not match.
        XCTAssertNil(WoolIntentSupport.bestTaskMatch(for: "no such task \(UUID().uuidString)", in: [task, unrelated]))
        // Intended fuzzy matching for a close name is still preserved.
        XCTAssertEqual(
            WoolIntentSupport.bestTaskMatch(for: "buy silk groceries \(marker)", in: [task, unrelated])?.id,
            task.id
        )
    }

    func testStartingReviewResumesInsteadOfDuplicatingInProgressReview() async throws {
        var first = StartWeeklyReviewIntent()
        _ = try await first.perform()
        var second = StartWeeklyReviewIntent()
        _ = try await second.perform()

        let context = ModelContext(WoolModelContainer.shared)
        let reviews = try context.fetch(FetchDescriptor<WeeklyReview>())
        XCTAssertEqual(reviews.filter { $0.status == .inProgress }.count, 1)
    }

    func testStartWeeklyReviewIntentPersistsAnInProgressStructuredReview() async throws {
        let context = ModelContext(WoolModelContainer.shared)
        try context.delete(model: WeeklyReview.self)
        try context.save()

        var intent = StartWeeklyReviewIntent()
        _ = try await intent.perform()

        let reviews = try context.fetch(FetchDescriptor<WeeklyReview>(sortBy: [SortDescriptor(\WeeklyReview.weekStart, order: .reverse)]))
        let review = try XCTUnwrap(reviews.first)

        XCTAssertEqual(review.status, .inProgress)
        XCTAssertNotNil(review.startedAt)
        XCTAssertEqual(review.checklistItems?.count, 6)
        let checklist = (review.checklistItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(checklist.map(\.kind), [.collect, .process, .stale, .organize, .review, .plan])
        XCTAssertEqual(checklist.map(\.isComplete), [false, false, false, false, false, false])
    }
}
#endif
