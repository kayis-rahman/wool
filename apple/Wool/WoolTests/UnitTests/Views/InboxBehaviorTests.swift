import XCTest
@testable import Wool

@MainActor
final class InboxBehaviorTests: XCTestCase {
    func testFilteringMatchesTitleAndNotesCaseInsensitively() {
        let titleMatch = TaskItem(title: "Book dentist appointment")
        let notesMatch = TaskItem(title: "Health admin", notes: "Call the DENTIST this week")
        let other = TaskItem(title: "Buy groceries")

        let filtered = InboxBehavior.filteredTasks([titleMatch, notesMatch, other], query: "dentist")
        XCTAssertEqual(filtered.map(\.title), [titleMatch.title, notesMatch.title])
    }

    func testFilteringWhitespaceReturnsAllInboxTasks() {
        let first = TaskItem(title: "First")
        let second = TaskItem(title: "Second")

        XCTAssertEqual(InboxBehavior.filteredTasks([first, second], query: "  ").map(\.title), [first.title, second.title])
    }

    func testTriageSummaryCoversZeroOneAndMany() {
        XCTAssertEqual(InboxBehavior.triageSummary(movedCount: 0), "Nothing was moved. Add more context to your captures.")
        XCTAssertEqual(InboxBehavior.triageSummary(movedCount: 1), "Moved 1 capture into Lists.")
        XCTAssertEqual(InboxBehavior.triageSummary(movedCount: 3), "Moved 3 captures into Lists.")
    }

    func testCompletingInboxItemRecordsCompletionAndRemovesItFromInbox() {
        let item = TaskItem(title: "Close the loop")

        item.status = .completed

        XCTAssertEqual(item.status, .completed)
        XCTAssertNotNil(item.completedAt)
        XCTAssertFalse(InboxBehavior.filteredTasks([item], query: "").contains { $0.status == .inbox })
    }

    func testOrganizedNextActionsIncludeFutureDatedWorkAndExcludeOtherCategories() {
        let futureAction = TaskItem(
            title: "Email client tomorrow",
            status: .nextAction,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        )
        let waiting = TaskItem(title: "Wait for reply", status: .waitingFor)
        let inbox = TaskItem(title: "Unclear thought", status: .inbox)

        let surfaced = InboxBehavior.organizedTasks([waiting, inbox, futureAction], status: .nextAction)

        XCTAssertEqual(surfaced.map(\.id), [futureAction.id])
    }

    func testProjectSuggestionMatchesExistingProjectName() {
        let project = Project(title: "Website redesign")
        let other = Project(title: "Home move")

        XCTAssertEqual(
            InboxBehavior.suggestedProject(in: [project, other], matching: "website redesign - fix header")?.id,
            project.id
        )
    }

    func testProjectSuggestionDoesNotLearnFromPreviousCorrections() {
        let project = Project(title: "Website redesign")

        XCTAssertNil(InboxBehavior.suggestedProject(in: [project], matching: "Email the client"))
        XCTAssertNil(InboxBehavior.suggestedProject(in: [project], matching: "Email the client again"))
    }
}
