import XCTest
@testable import Wool

@MainActor
final class FeatureFlagsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "Wool.FeatureFlagsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = ""
        super.tearDown()
    }

    func testAllKnownFlagsDefaultToDisabled() {
        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertTrue(FeatureFlag.allCases.allSatisfy { !$0.defaultValue })
        XCTAssertTrue(flags.statuses.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(flags.source, .defaults)
        XCTAssertEqual(flags.statuses.count, 3)
    }

    func testRegistryContainsSupportMetadataAndNamespacedKeys() {
        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertEqual(
            flags.statuses.map(\.flag.rawValue),
            [
                "features.malayalamVoice",
                "features.gmailIntegration",
                "features.githubProjectsIntegration"
            ]
        )
        XCTAssertTrue(flags.statuses.allSatisfy { !$0.owner.isEmpty && !$0.intendedRemovalDate.isEmpty })
    }

    func testFailedRemoteRefreshKeepsDefaultsAndDoesNotCreateAnActiveChange() async {
        let remote = FakeRemoteStore(result: .failure(FakeError.unavailable))
        let flags = FeatureFlags(remoteStore: remote, userDefaults: defaults)

        await flags.refreshRemoteConfiguration()

        XCTAssertFalse(flags.malayalamVoiceEnabled)
        XCTAssertNil(defaults.data(forKey: FeatureFlags.cacheKey))
        XCTAssertNotNil(flags.lastRefreshError)
    }

    func testRemoteRefreshIsCachedButOnlyAppliesOnNextLaunch() async {
        let remote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 4,
            updatedAt: Date(timeIntervalSince1970: 10),
            flags: [
                "features.malayalamVoice": true,
                "unknown.flag": true
            ]
        )))
        let activeSession = FeatureFlags(remoteStore: remote, userDefaults: defaults)

        await activeSession.refreshRemoteConfiguration()

        XCTAssertFalse(activeSession.malayalamVoiceEnabled)
        XCTAssertEqual(activeSession.pendingConfigVersion, 4)

        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)
        XCTAssertTrue(nextSession.malayalamVoiceEnabled)
        XCTAssertFalse(nextSession.gmailIntegrationEnabled)
        XCTAssertEqual(nextSession.source, .cache)
        XCTAssertEqual(nextSession.configVersion, 4)
    }

    func testEveryKnownFlagCanBeEnabledByRemoteConfigurationOnNextLaunch() async {
        let remote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 6,
            updatedAt: Date(timeIntervalSince1970: 600),
            flags: Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { ($0.rawValue, true) })
        )))
        let session = FeatureFlags(remoteStore: remote, userDefaults: defaults)

        await session.refreshRemoteConfiguration()

        XCTAssertTrue(FeatureFlag.allCases.allSatisfy { !session.isEnabled($0) })
        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)
        XCTAssertTrue(FeatureFlag.allCases.allSatisfy { nextSession.isEnabled($0) })
    }

    func testPartialCachedConfigurationSafelyFillsMissingFlagsWithDefaults() {
        writeCache(configVersion: 2, fetchedAt: Date(timeIntervalSince1970: 20), values: [
            "features.gmailIntegration": true
        ])

        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertFalse(flags.malayalamVoiceEnabled)
        XCTAssertTrue(flags.gmailIntegrationEnabled)
        XCTAssertFalse(flags.githubProjectsIntegrationEnabled)
        XCTAssertEqual(flags.statuses.count, FeatureFlag.allCases.count)
    }

    func testUnknownCachedKeysAreIgnored() {
        writeCache(configVersion: 3, fetchedAt: Date(timeIntervalSince1970: 30), values: [
            "unknown.flag": true
        ])

        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertTrue(flags.statuses.allSatisfy { !$0.isEnabled })
    }

    func testMalformedCacheFallsBackToSafeDefaults() {
        defaults.set(Data("not-json".utf8), forKey: FeatureFlags.cacheKey)

        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertEqual(flags.source, .defaults)
        XCTAssertNil(flags.configVersion)
        XCTAssertNil(flags.fetchedAt)
        XCTAssertTrue(flags.statuses.allSatisfy { !$0.isEnabled })
    }

    func testUnsupportedCacheSchemaFallsBackToSafeDefaults() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 99,
            "configVersion": 10,
            "fetchedAt": "2026-08-30T00:00:00Z",
            "values": ["features.malayalamVoice": true]
        ])
        defaults.set(data, forKey: FeatureFlags.cacheKey)

        let flags = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertEqual(flags.source, .defaults)
        XCTAssertFalse(flags.malayalamVoiceEnabled)
    }

    func testRemoteUnknownKeysCannotEnableKnownFlags() async {
        let remote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 7,
            updatedAt: Date(),
            flags: ["unknown.flag": true]
        )))
        let session = FeatureFlags(remoteStore: remote, userDefaults: defaults)

        await session.refreshRemoteConfiguration()
        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertTrue(nextSession.statuses.allSatisfy { !$0.isEnabled })
    }

    func testRepeatedRefreshDoesNotChangeTheActiveSnapshot() async {
        let remote = SequencedRemoteStore(results: [
            .success(RemoteFeatureFlagConfiguration(
                configVersion: 8,
                updatedAt: Date(),
                flags: ["features.gmailIntegration": true]
            )),
            .success(RemoteFeatureFlagConfiguration(
                configVersion: 9,
                updatedAt: Date(),
                flags: ["features.gmailIntegration": false]
            ))
        ])
        let session = FeatureFlags(remoteStore: remote, userDefaults: defaults)

        await session.refreshRemoteConfiguration()
        await session.refreshRemoteConfiguration()

        XCTAssertFalse(session.gmailIntegrationEnabled)
        XCTAssertEqual(session.pendingConfigVersion, 9)
        XCTAssertFalse(FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults).gmailIntegrationEnabled)
    }

    func testCacheTimestampIsRecordedForDiagnostics() async {
        let expectedDate = Date(timeIntervalSince1970: 1234)
        let remote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 11,
            updatedAt: Date(timeIntervalSince1970: 1000),
            flags: [:]
        )))
        let session = FeatureFlags(remoteStore: remote, userDefaults: defaults, now: { expectedDate })

        await session.refreshRemoteConfiguration()
        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertEqual(nextSession.fetchedAt, expectedDate)
    }

    func testFailedRefreshAfterCachedConfigurationPreservesLastKnownState() async {
        writeCache(configVersion: 12, fetchedAt: Date(), values: [
            "features.githubProjectsIntegration": true
        ])
        let session = FeatureFlags(
            remoteStore: FakeRemoteStore(result: .failure(FakeError.unavailable)),
            userDefaults: defaults
        )

        await session.refreshRemoteConfiguration()

        XCTAssertTrue(session.githubProjectsIntegrationEnabled)
        XCTAssertEqual(session.configVersion, 12)
        XCTAssertEqual(session.source, .cache)
    }

    func testEqualVersionRefreshCanCorrectAnExistingCachedPayload() async {
        writeCache(configVersion: 13, fetchedAt: Date(), values: [
            "features.gmailIntegration": true
        ])
        let session = FeatureFlags(
            remoteStore: FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
                configVersion: 13,
                updatedAt: Date(),
                flags: ["features.gmailIntegration": false]
            ))),
            userDefaults: defaults
        )

        await session.refreshRemoteConfiguration()

        XCTAssertTrue(session.gmailIntegrationEnabled)
        XCTAssertEqual(session.pendingConfigVersion, 13)
        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)
        XCTAssertFalse(nextSession.gmailIntegrationEnabled)
    }

    func testEmptyRemotePayloadDisablesAllKnownFlagsOnNextLaunch() async {
        let session = FeatureFlags(
            remoteStore: FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
                configVersion: 14,
                updatedAt: Date(),
                flags: [:]
            ))),
            userDefaults: defaults
        )

        await session.refreshRemoteConfiguration()
        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)

        XCTAssertTrue(nextSession.statuses.allSatisfy { !$0.isEnabled })
    }

    func testOlderRemoteConfigurationCannotReplaceNewerCache() async {
        let firstRemote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 5,
            updatedAt: Date(),
            flags: ["features.gmailIntegration": true]
        )))
        let firstSession = FeatureFlags(remoteStore: firstRemote, userDefaults: defaults)
        await firstSession.refreshRemoteConfiguration()

        let olderRemote = FakeRemoteStore(result: .success(RemoteFeatureFlagConfiguration(
            configVersion: 4,
            updatedAt: Date(),
            flags: ["features.gmailIntegration": false]
        )))
        let secondSession = FeatureFlags(remoteStore: olderRemote, userDefaults: defaults)
        await secondSession.refreshRemoteConfiguration()

        let nextSession = FeatureFlags(remoteStore: FakeRemoteStore(), userDefaults: defaults)
        XCTAssertTrue(nextSession.gmailIntegrationEnabled)
        XCTAssertNil(secondSession.pendingConfigVersion)
    }

    private func writeCache(configVersion: Int, fetchedAt: Date, values: [String: Bool]) {
        let cache = TestCacheEnvelope(
            schemaVersion: 1,
            configVersion: configVersion,
            fetchedAt: fetchedAt,
            values: values
        )
        defaults.set(try! JSONEncoder().encode(cache), forKey: FeatureFlags.cacheKey)
    }

}

@MainActor
private final class FakeRemoteStore: FeatureFlagsRemoteStore {
    let result: Result<RemoteFeatureFlagConfiguration, Error>

    init(result: Result<RemoteFeatureFlagConfiguration, Error> = .failure(FakeError.unavailable)) {
        self.result = result
    }

    func fetchConfiguration() async throws -> RemoteFeatureFlagConfiguration {
        try result.get()
    }
}

@MainActor
private final class SequencedRemoteStore: FeatureFlagsRemoteStore {
    private var results: [Result<RemoteFeatureFlagConfiguration, Error>]

    init(results: [Result<RemoteFeatureFlagConfiguration, Error>]) {
        self.results = results
    }

    func fetchConfiguration() async throws -> RemoteFeatureFlagConfiguration {
        try results.removeFirst().get()
    }
}

private struct TestCacheEnvelope: Codable {
    let schemaVersion: Int
    let configVersion: Int
    let fetchedAt: Date
    let values: [String: Bool]
}

private enum FakeError: Error {
    case unavailable
}
