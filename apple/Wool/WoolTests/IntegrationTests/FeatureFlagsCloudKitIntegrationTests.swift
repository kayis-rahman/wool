import CloudKit
import XCTest
@testable import Wool

/// Opt-in Production-config verification. It is intentionally excluded from
/// ordinary tests because it requires the signed-in test Apple Account and a
/// promoted FeatureFlagsConfig record.
@MainActor
final class FeatureFlagsCloudKitIntegrationTests: XCTestCase {
    func testProductionFeatureFlagRecordIsReadable() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["WOOL_CLOUDKIT_FEATURE_FLAGS_INTEGRATION"] == "1",
            "CloudKit feature-flag integration is opt-in."
        )

        let store = CloudKitFeatureFlagsRemoteStore()
        let configuration = try await store.fetchConfiguration()

        XCTAssertGreaterThan(configuration.configVersion, 0)
        XCTAssertFalse(configuration.updatedAt.timeIntervalSince1970 <= 0)
        XCTAssertTrue(Set(configuration.flags.keys).isSuperset(of: Set(FeatureFlag.allCases.map(\.rawValue))))
    }
}
