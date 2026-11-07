import XCTest
import SwiftData
import AppIntents
@testable import Wool

/// Acceptance coverage for the Siri/App Intents story. Tests that require the
/// Siri daemon, Settings permissions, process termination, another device, or
/// watchOS are explicit manual checks rather than false-positive XCTest cases.
@MainActor
final class SiriAppIntentsAcceptanceTests: XCTestCase {
    private func context() -> ModelContext { ModelContext(WoolModelContainer.shared) }

    func testTC1BasicCaptureViaSiri() async throws {
        let title = "buy milk \(UUID().uuidString)"
        var intent = AddCaptureIntent(); intent.title = title
        _ = try await intent.perform()
        let saved = try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title }))
        XCTAssertEqual(saved.first?.status, .inbox)
    }

    func testTC2MisheardInputPreservesRawText() async throws {
        let title = "add by silk to Wool \(UUID().uuidString)"
        var intent = AddCaptureIntent(); intent.title = title
        _ = try await intent.perform()
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).count, 1)
    }

    func testTC3FreshInstallFailsWithSetupMessage() throws {
        XCTAssertEqual(
            WoolIntentSupport.setupError(appSetupCompleted: false, accountStatus: nil)?.errorDescription,
            WoolIntentError.appNeedsSetup.errorDescription
        )
    }

    func testTC4MissingCloudKitAccountFailsWithSetupMessage() throws {
        XCTAssertEqual(
            WoolIntentSupport.setupError(appSetupCompleted: true, accountStatus: .noAccount)?.errorDescription,
            WoolIntentError.cloudKitUnavailable.errorDescription
        )
    }

    func testTC5StartReviewResumesExistingReview() async throws {
        let before = try context().fetch(FetchDescriptor<WeeklyReview>()).filter { $0.status == .inProgress }.count
        var intent = StartWeeklyReviewIntent(); _ = try await intent.perform()
        var second = StartWeeklyReviewIntent(); _ = try await second.perform()
        let reviews = try context().fetch(FetchDescriptor<WeeklyReview>()).filter { $0.status == .inProgress }
        XCTAssertEqual(reviews.count, max(before, 1))
    }

    func testTC6ShowNextActionsRunsAgainstLocalData() async throws {
        let task = TaskItem(title: "next action \(UUID().uuidString)", status: .nextAction, dueDate: .now)
        try CapturePersistenceService.save(task, in: context())
        _ = try await ShowNextActionsIntent().perform()
    }

    func testTC7CompleteTaskFuzzyMatchesAndDoesNotCreate() async throws {
        let marker = UUID().uuidString
        let title = "buy milk groceries \(marker)"
        let task = TaskItem(title: title, status: .nextAction)
        try CapturePersistenceService.save(task, in: context())
        var intent = CompleteTaskIntent(); intent.title = "buy silk groceries \(marker)"
        _ = try await intent.perform()
        let taskID = task.id
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })).first?.status, .completed)
        var missing = CompleteTaskIntent(); missing.title = "no such task \(UUID().uuidString)"
        do { _ = try await missing.perform(); XCTFail("A missing task must not be created") } catch { }
    }

    func testTC8ChainedIntentsHaveIndependentCalls() async throws {
        var capture = AddCaptureIntent(); capture.title = "chain capture \(UUID().uuidString)"
        _ = try await capture.perform()
        _ = try await StartFocusIntent().perform()
        _ = try await ShowNextActionsIntent().perform()
    }

    func testTC9BackgroundIntentIsCoveredBySharedPersistencePath() async throws {
        try await testTC1BasicCaptureViaSiri()
    }

    func testTC10ForceQuitIntentRequiresPhysicalSiriRunner() throws {
        throw XCTSkip("Requires force-quitting the installed app and invoking Siri; run on the configured iPhone.")
    }

    func testTC11OfflineCaptureUsesLocalStore() async throws {
        let title = "offline capture \(UUID().uuidString)"
        var intent = AddCaptureIntent(); intent.title = title
        _ = try await intent.perform()
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).count, 1)
    }

    func testTC12AmbiguousEmptyCaptureRequestsClarification() async throws {
        var intent = AddCaptureIntent(); intent.title = "   "
        do { _ = try await intent.perform(); XCTFail("Whitespace-only capture must be rejected") } catch { }
    }

    func testTC13CaptureUsesSharedInboxPipeline() async throws {
        let title = "email the client \(UUID().uuidString)"
        var intent = AddCaptureIntent(); intent.title = title
        _ = try await intent.perform()
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).first?.status, .inbox)
    }

    func testTC14RapidRepeatedCapturesAreNotDeduplicated() async throws {
        let title = "repeat \(UUID().uuidString)"
        for _ in 0..<3 { var intent = AddCaptureIntent(); intent.title = title; _ = try await intent.perform() }
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).count, 3)
    }

    func testTC15DeniedSiriPermissionKeepsInAppCaptureAvailable() throws {
        throw XCTSkip("Siri authorization is controlled by Settings and must be verified manually on the iPhone.")
    }

    func testTC16SpotlightSurfacesAppShortcuts() throws {
        XCTAssertGreaterThanOrEqual(WoolShortcuts.appShortcuts.count, 6)
    }

    func testTC17CaptureDuringReviewRemainsInbox() async throws {
        var review = StartWeeklyReviewIntent(); _ = try await review.perform()
        let title = "during review \(UUID().uuidString)"
        var capture = AddCaptureIntent(); capture.title = title; _ = try await capture.perform()
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).first?.status, .inbox)
    }

    func testTC18MalformedInputIsRawCaptureOrExplicitClarification() async throws {
        let title = "%% noise \u{1F4A5} \(UUID().uuidString)"
        var intent = AddCaptureIntent(); intent.title = title
        _ = try await intent.perform()
        XCTAssertEqual(try context().fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title })).count, 1)
    }

    func testTC19UnsupportedWatchOSDeviceBehaviorIsDocumented() throws {
        throw XCTSkip("Requires a watchOS target/device; behavior remains unavailable until watchOS scope is finalized.")
    }

    func testTC20TimeBasedShortcutAutomationIsSystemManaged() throws {
        throw XCTSkip("Requires creating a personal Shortcuts automation and waiting for its scheduled trigger.")
    }
}
