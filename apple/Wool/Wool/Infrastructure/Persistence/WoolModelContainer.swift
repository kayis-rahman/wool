import Foundation
import SwiftData

enum WoolModelContainer {
    static let cloudKitContainerIdentifier = "iCloud.com.sparkage.wool"
    static let cloudKitIntegrationConfirmation = "DEDICATED_TEST_APPLE_ACCOUNT"
    static let appSetupCompletedKey = "wool.appSetupCompleted"
    static let pendingDestinationKey = "wool.pendingDestination"

    static let schema = Schema(versionedSchema: WoolSchemaV1.self)

    /// A unique local store keeps each UI-test run isolated from CloudKit and
    /// from the user's production database. Tests that relaunch the app mid-test
    /// to verify persistence pass a stable `WOOL_UI_TEST_STORE_ID` so every
    /// relaunch in that test reopens the same file. Tests that don't set it still
    /// need a store stable for the lifetime of this process (e.g. repeated
    /// `makeIntentContainer()` calls simulating separate App Intent processes
    /// must resolve to the same file), so the fallback identifier is generated
    /// once and cached, not regenerated on every access.
    private static let fallbackUITestStoreIdentifier = UUID().uuidString

    static var uiTestStoreURL: URL {
        let identifier = ProcessInfo.processInfo.environment["WOOL_UI_TEST_STORE_ID"] ?? fallbackUITestStoreIdentifier
        return FileManager.default.temporaryDirectory
            .appending(path: "WoolUITests-\(identifier).sqlite")
    }

    static let shared: ModelContainer = {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: WoolMigrationPlan.self,
                configurations: configuration(isTesting: isTestingProcess)
            )
        } catch {
            fatalError("Unable to create Wool model container: \(error)")
        }
    }()

    static func configuration(isTesting: Bool) -> ModelConfiguration {
        if isTesting {
            ModelConfiguration(
                "WoolUITests",
                schema: schema,
                url: uiTestStoreURL,
                cloudKitDatabase: .none
            )
        } else {
            ModelConfiguration(
                "Wool",
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }
    }

    static var isTestingProcess: Bool {
        if isCloudKitIntegrationProcess {
            return false
        }

        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("-ui-testing") ||
            processInfo.environment["WOOL_UI_TESTING"] == "1" ||
            processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// XCTest normally receives an isolated local store. The physical-device
    /// CloudKit integration suite can opt into the real private store only
    /// after an explicit acknowledgement that it uses a dedicated test account.
    static var isCloudKitIntegrationProcess: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["WOOL_CLOUDKIT_INTEGRATION"] == "1" &&
            environment["WOOL_CLOUDKIT_INTEGRATION_CONFIRM"] == cloudKitIntegrationConfirmation
    }

    /// App Intents can run before the app has ever opened. Keep that
    /// recoverable setup failure away from `shared`'s fatalError path.
    static var appSetupCompleted: Bool {
        isTestingProcess || UserDefaults.standard.bool(forKey: appSetupCompletedKey)
    }

    static func makeIntentContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: configuration(isTesting: isTestingProcess))
    }
}
