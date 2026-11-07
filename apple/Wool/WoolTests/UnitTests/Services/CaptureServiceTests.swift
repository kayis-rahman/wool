import XCTest
@testable import Wool

@MainActor
final class CaptureServiceTests: XCTestCase {
    func testProcessCaptureReturnsAnUnsavedItem() async {
        let service = CaptureService(allowsFoundationModel: false)
        let item = await service.processCapture(text: "Email the client tomorrow about the work plan")

        XCTAssertFalse(item.title.isEmpty)
        XCTAssertEqual(item.title, "Email the client tomorrow about the work plan")
        XCTAssertEqual(item.status, .nextAction)
        XCTAssertEqual(item.contextTags, ["area:Work"])
        XCTAssertNotNil(item.dueDate)
        XCTAssertNil(item.modelContext)
    }

    func testProcessInboxCaptureKeepsClassifiableCaptureInInbox() async {
        let service = CaptureService(allowsFoundationModel: false)
        let item = service.processInboxCapture(text: "Email the client tomorrow about the work plan")

        XCTAssertEqual(item.status, .inbox)
        XCTAssertEqual(item.contextTags, ["area:Work"])
        XCTAssertNotNil(item.dueDate)
        XCTAssertNil(item.modelContext)
    }

    func testProcessInboxCapturePreservesVeryLongText() {
        let service = CaptureService(allowsFoundationModel: false)
        let paragraph = String(repeating: "Review the project notes and decide the next step. ", count: 200)

        let item = service.processInboxCapture(text: paragraph)

        XCTAssertEqual(item.status, .inbox)
        XCTAssertEqual(item.title, paragraph.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertGreaterThan(item.title.count, 4_000)
    }

    func testProcessCapturePreservesNotesInTheReturnedItem() async {
        let service = CaptureService(allowsFoundationModel: false)
        let item = await service.processCapture(text: "Plan family dinner\nCheck dietary requirements")

        XCTAssertEqual(item.title, "Plan family dinner")
        XCTAssertEqual(item.notes, "Check dietary requirements")
        XCTAssertEqual(item.contextTags, ["area:Personal"])
    }

    func testProcessCaptureMapsWaitingAndSomedayLanguageToStatuses() async {
        let service = CaptureService(allowsFoundationModel: false)

        let waiting = await service.processCapture(text: "Waiting for the client reply")
        let someday = await service.processCapture(text: "Maybe learn woodworking someday")

        XCTAssertEqual(waiting.status, .waitingFor)
        XCTAssertEqual(someday.status, .somedayMaybe)
    }

    func testProcessCaptureLeavesUnclearThoughtsInInbox() async {
        let service = CaptureService(allowsFoundationModel: false)
        let item = await service.processCapture(text: "Ideas for the garden")

        XCTAssertEqual(item.status, .inbox)
        XCTAssertNil(item.dueDate)
        XCTAssertTrue(item.contextTags.isEmpty)
        XCTAssertNil(item.modelContext)
    }

    func testBasicTriageSuggestsNextActionHealthAndNextWeekday() async throws {
        let item = await CaptureService(allowsFoundationModel: false).processCapture(text: "Call dentist Tuesday")

        XCTAssertEqual(item.status, .nextAction)
        XCTAssertEqual(item.contextTags, ["area:Health"])
        let dueDate = try XCTUnwrap(item.dueDate)
        XCTAssertEqual(Calendar.current.component(.weekday, from: dueDate), 3) // Tuesday
        XCTAssertGreaterThan(dueDate, .now)
    }

    func testHeuristicFallbackLeavesBuyMilkWithoutAreaOrDueDate() async {
        let item = await CaptureService(allowsFoundationModel: false).processCapture(text: "Buy milk")

        XCTAssertEqual(item.title, "Buy milk")
        XCTAssertEqual(item.status, .nextAction)
        XCTAssertTrue(item.contextTags.isEmpty)
        XCTAssertNil(item.dueDate)
    }

    func testNoDueDateIsInventedForUnscheduledCapture() async {
        let item = await CaptureService(allowsFoundationModel: false).processCapture(text: "Read that book")

        XCTAssertNil(item.dueDate)
    }
}
