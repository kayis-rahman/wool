import XCTest
import SwiftData

@testable import Wool

@MainActor
final class InboxTriagePersistenceTests: XCTestCase {
    func testTriagePersistsFutureNextActionAndMakesItBrowsableOutsideInbox() async throws {
        let title = "Email the client tomorrow about the work plan \(UUID().uuidString)"
        let item = TaskItem(title: title, status: .inbox)
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(item)
        try context.save()

        let moved = await InboxTriageService.triage(
            [item],
            using: CaptureService(allowsFoundationModel: false)
        )
        try context.save()

        XCTAssertEqual(moved.map(\.id), [item.id])

        let persisted = try XCTUnwrap(
            context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).first
        )
        XCTAssertEqual(persisted.status, .nextAction)
        XCTAssertEqual(persisted.contextTags, ["area:Work"])
        XCTAssertNotNil(persisted.dueDate)
        let inboxItems = [persisted].filter { $0.status == .inbox }
        XCTAssertFalse(inboxItems.contains { $0.id == persisted.id })
        XCTAssertEqual(
            InboxBehavior.organizedTasks([persisted], status: .nextAction).map(\.id),
            [persisted.id]
        )
    }
}
