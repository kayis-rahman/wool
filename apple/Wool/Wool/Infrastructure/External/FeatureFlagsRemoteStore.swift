import CloudKit
import Foundation

struct RemoteFeatureFlagConfiguration: Codable, Equatable {
    let configVersion: Int
    let updatedAt: Date
    let flags: [String: Bool]
}

@MainActor
protocol FeatureFlagsRemoteStore {
    func fetchConfiguration() async throws -> RemoteFeatureFlagConfiguration
}

/// Reads the release configuration from the public CloudKit database.
///
/// The record must be created in CloudKit Development and promoted to
/// Production before a remote rollout is attempted.
@MainActor
final class CloudKitFeatureFlagsRemoteStore: FeatureFlagsRemoteStore {
    static let recordType = "FeatureFlagsConfig"
    static let recordName = "production-v1"

    private let database: CKDatabase

    init(containerIdentifier: String = WoolModelContainer.cloudKitContainerIdentifier) {
        let container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
    }

    func fetchConfiguration() async throws -> RemoteFeatureFlagConfiguration {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        let record = try await database.record(for: recordID)

        guard let version = (record["configVersion"] as? NSNumber)?.intValue,
              let updatedAt = record["updatedAt"] as? Date,
              let flagsJSON = record["flags"] as? String,
              let data = flagsJSON.data(using: .utf8),
              let flags = try JSONSerialization.jsonObject(with: data) as? [String: Bool]
        else {
            throw FeatureFlagsRemoteStoreError.invalidRecord
        }

        return RemoteFeatureFlagConfiguration(
            configVersion: version,
            updatedAt: updatedAt,
            flags: flags
        )
    }
}

enum FeatureFlagsRemoteStoreError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            "The CloudKit feature-flag record is missing or malformed."
        }
    }
}
