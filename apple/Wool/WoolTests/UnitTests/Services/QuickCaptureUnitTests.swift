import XCTest
@testable import Wool

@MainActor
final class QuickCaptureUnitTests: XCTestCase {
    private let service = CaptureService(allowsFoundationModel: false)

    func testWhitespaceOnlyCaptureIsEmptyAndRemainsInbox() {
        let item = service.processInboxCapture(text: "   \n\t  ")

        XCTAssertEqual(item.title, "")
        XCTAssertEqual(item.status, .inbox)
        XCTAssertNil(item.modelContext)
    }

    func testBasicCaptureCreatesInboxItemWithTimestamp() {
        let before = Date()
        let item = service.processInboxCapture(text: "Buy milk")

        XCTAssertEqual(item.title, "Buy milk")
        XCTAssertEqual(item.status, .inbox)
        XCTAssertGreaterThanOrEqual(item.createdAt, before)
        XCTAssertNil(item.modelContext)
    }

    func testSpecialCharactersEmojiAndNonEnglishTextArePreserved() {
        let inputs = ["Fix bug #123 @ 50% done!", "Buy 🥛 and 🍞", "Acheter du lait pour demain"]

        for input in inputs {
            let item = service.processInboxCapture(text: input)
            XCTAssertEqual(item.title, input)
            XCTAssertEqual(item.status, .inbox)
        }
    }

    func testLongCaptureIsPreservedWhileFoundationModelPromptIsBounded() {
        let input = String(repeating: "Review the project notes and decide the next step. ", count: 200)
        let item = service.processInboxCapture(text: input)
        let prompt = CaptureService.foundationModelPrompt(for: input)

        XCTAssertEqual(item.title, input.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertGreaterThan(item.title.count, CaptureService.foundationModelInputLimit)
        XCTAssertEqual(prompt.count, CaptureService.foundationModelInputLimit)
        XCTAssertTrue(input.hasPrefix(prompt))
    }
}
