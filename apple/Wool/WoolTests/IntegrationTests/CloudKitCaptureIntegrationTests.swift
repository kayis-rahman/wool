import XCTest
import SwiftData

#if canImport(AppIntents)
import AppIntents
#endif

@testable import Wool

/// A real private-CloudKit test, intentionally excluded from routine test runs.
///
/// Run its writer on one physical device and its reader on another device signed
/// into the same dedicated Apple Account. See docs/siri-cloudkit-verification.md.
#if canImport(AppIntents)
@MainActor
final class CloudKitCaptureIntegrationTests: XCTestCase {
    private enum Role: String {
        case writer
        case reader
    }

    private struct Configuration {
        let role: Role
        let runID: UUID

        var title: String {
            "Email the CloudKit test client tomorrow about the work plan [Wool CloudKit Integration \(runID.uuidString)]"
        }
    }

    func testWriterCreatesCaptureThroughTheRealAppIntent() async throws {
        let configuration = try integrationConfiguration(requiring: .writer)
        XCTAssertFalse(WoolModelContainer.isTestingProcess)

        let context = ModelContext(WoolModelContainer.shared)
        XCTAssertTrue(try items(titled: configuration.title, in: context).isEmpty)

        var intent = AddCaptureIntent()
        intent.title = configuration.title
        _ = try await intent.perform()

        let item = try XCTUnwrap(items(titled: configuration.title, in: context).first)
        assertExpectedCapture(item, title: configuration.title)
    }

    func testReaderReceivesCaptureFromTheOtherPhysicalDevice() async throws {
        let configuration = try integrationConfiguration(requiring: .reader)
        XCTAssertFalse(WoolModelContainer.isTestingProcess)

        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            let context = ModelContext(WoolModelContainer.shared)
            if let item = try items(titled: configuration.title, in: context).first {
                assertExpectedCapture(item, title: configuration.title)
                context.delete(item)
                try context.save()
                return
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        XCTFail("Timed out waiting for CloudKit capture \(configuration.runID.uuidString). Ensure the writer passed and both devices use the dedicated test Apple Account.")
    }

    private func integrationConfiguration(requiring requiredRole: Role) throws -> Configuration {
        let environment = ProcessInfo.processInfo.environment
        guard environment["WOOL_CLOUDKIT_INTEGRATION"] == "1" else {
            throw XCTSkip("CloudKit integration is opt-in. Use scripts/run-cloudkit-capture-integration.sh with two dedicated-account devices.")
        }
        guard environment["WOOL_CLOUDKIT_INTEGRATION_CONFIRM"] == WoolModelContainer.cloudKitIntegrationConfirmation else {
            XCTFail("CloudKit integration requires WOOL_CLOUDKIT_INTEGRATION_CONFIRM=\(WoolModelContainer.cloudKitIntegrationConfirmation).")
            throw XCTSkip("Missing dedicated-account confirmation.")
        }
        guard environment["WOOL_CAPTURE_FORCE_HEURISTICS"] == "1" else {
            XCTFail("CloudKit integration requires deterministic heuristic classification.")
            throw XCTSkip("Missing deterministic classification configuration.")
        }
        guard let role = environment["WOOL_CLOUDKIT_INTEGRATION_ROLE"].flatMap(Role.init(rawValue:)), role == requiredRole else {
            throw XCTSkip("This invocation is configured for the other integration-test role.")
        }
        guard let value = environment["WOOL_CLOUDKIT_INTEGRATION_RUN_ID"], let runID = UUID(uuidString: value) else {
            XCTFail("Provide WOOL_CLOUDKIT_INTEGRATION_RUN_ID as a UUID.")
            throw XCTSkip("Missing run identifier.")
        }
        return Configuration(role: role, runID: runID)
    }

    private func items(titled title: String, in context: ModelContext) throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title }))
    }

    private func assertExpectedCapture(_ item: TaskItem, title: String) {
        XCTAssertEqual(item.title, title)
        XCTAssertEqual(item.status, .inbox)
        XCTAssertEqual(item.contextTags, ["area:Work"])
        let dueDate = try? XCTUnwrap(item.dueDate)
        XCTAssertNotNil(dueDate)
        if let dueDate {
            let expected = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            XCTAssertTrue(Calendar.current.isDate(dueDate, inSameDayAs: expected))
        }
        XCTAssertNil(item.project)
    }
}
#endif
