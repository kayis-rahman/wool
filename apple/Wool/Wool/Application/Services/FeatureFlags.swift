import Foundation
import Observation
import os

enum FeatureFlag: String, CaseIterable, Identifiable, Codable {
    case malayalamVoice = "features.malayalamVoice"
    case gmailIntegration = "features.gmailIntegration"
    case githubProjectsIntegration = "features.githubProjectsIntegration"

    var id: String { rawValue }
    var defaultValue: Bool { false }

    var owner: String {
        switch self {
        case .malayalamVoice:
            "Wool Product"
        case .gmailIntegration, .githubProjectsIntegration:
            "Wool Integrations"
        }
    }

    // Remove the flag after its rollout is complete.
    var intendedRemovalDate: String { "2027-01-31" }
}

enum FeatureFlagSource: String, Codable {
    case defaults
    case cache
}

struct FeatureFlagSnapshot: Codable, Equatable {
    let values: [String: Bool]

    func value(for flag: FeatureFlag) -> Bool {
        values[flag.rawValue] ?? flag.defaultValue
    }
}

struct FeatureFlagStatus: Identifiable {
    let flag: FeatureFlag
    let isEnabled: Bool
    let defaultValue: Bool
    let owner: String
    let intendedRemovalDate: String

    var id: String { flag.id }
}

private struct FeatureFlagCacheEnvelope: Codable {
    let schemaVersion: Int
    let configVersion: Int
    let fetchedAt: Date
    let values: [String: Bool]
}

@MainActor
@Observable
final class FeatureFlags {
    static let shared = FeatureFlags()
    static let cacheKey = "features.remoteConfig.v1"
    static let diagnosticsEnvironmentKey = "WOOL_FEATURE_FLAGS_DEBUG"

    private let remoteStore: any FeatureFlagsRemoteStore
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let logger = Logger(subsystem: "com.sparkage.wool", category: "FeatureFlags")

    private(set) var snapshot: FeatureFlagSnapshot
    private(set) var source: FeatureFlagSource
    private(set) var configVersion: Int?
    private(set) var fetchedAt: Date?
    private(set) var pendingConfigVersion: Int?
    private(set) var lastRefreshError: String?

    var malayalamVoiceEnabled: Bool { snapshot.value(for: .malayalamVoice) }
    var gmailIntegrationEnabled: Bool {
        snapshot.value(for: .gmailIntegration) ||
            ProcessInfo.processInfo.environment["WOOL_GMAIL_UI_TESTING"] == "1"
    }
    var githubProjectsIntegrationEnabled: Bool { snapshot.value(for: .githubProjectsIntegration) }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        snapshot.value(for: flag)
    }

    var statuses: [FeatureFlagStatus] {
        FeatureFlag.allCases.map { flag in
            FeatureFlagStatus(
                flag: flag,
                isEnabled: snapshot.value(for: flag),
                defaultValue: flag.defaultValue,
                owner: flag.owner,
                intendedRemovalDate: flag.intendedRemovalDate
            )
        }
    }

    #if DEBUG
    var diagnosticsEnabled: Bool {
        ProcessInfo.processInfo.environment[Self.diagnosticsEnvironmentKey] == "1" ||
            userDefaults.bool(forKey: Self.diagnosticsEnvironmentKey)
    }
    #else
    var diagnosticsEnabled: Bool { false }
    #endif

    init(
        remoteStore: (any FeatureFlagsRemoteStore)? = nil,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.remoteStore = remoteStore ?? CloudKitFeatureFlagsRemoteStore()
        self.userDefaults = userDefaults
        self.now = now

        if let cache = Self.loadCache(from: userDefaults), cache.schemaVersion == 1 {
            snapshot = Self.snapshot(values: cache.values)
            source = .cache
            configVersion = cache.configVersion
            fetchedAt = cache.fetchedAt
        } else {
            snapshot = Self.defaultSnapshot()
            source = .defaults
        }
    }

    /// Fetches remote configuration into the cache. The active snapshot is
    /// deliberately not changed; the fetched values take effect next launch.
    func refreshRemoteConfiguration() async {
        do {
            let remote = try await remoteStore.fetchConfiguration()
            guard remote.configVersion >= (configVersion ?? 0) else {
                logger.notice("Ignored older feature flag configuration")
                return
            }

            let envelope = FeatureFlagCacheEnvelope(
                schemaVersion: 1,
                configVersion: remote.configVersion,
                fetchedAt: now(),
                values: Self.normalizedValues(remote.flags)
            )
            guard let data = try? JSONEncoder().encode(envelope) else {
                lastRefreshError = "Unable to encode feature flag cache"
                return
            }

            userDefaults.set(data, forKey: Self.cacheKey)
            pendingConfigVersion = remote.configVersion
            lastRefreshError = nil
            logger.info("Cached feature flag configuration for next launch")
        } catch {
            lastRefreshError = error.localizedDescription
            logger.debug("Feature flag refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func defaultSnapshot() -> FeatureFlagSnapshot {
        snapshot(values: [:])
    }

    private static func snapshot(values: [String: Bool]) -> FeatureFlagSnapshot {
        FeatureFlagSnapshot(values: normalizedValues(values))
    }

    private static func normalizedValues(_ values: [String: Bool]) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { flag in
            (flag.rawValue, values[flag.rawValue] ?? flag.defaultValue)
        })
    }

    private static func loadCache(from userDefaults: UserDefaults) -> FeatureFlagCacheEnvelope? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(FeatureFlagCacheEnvelope.self, from: data)
    }
}
