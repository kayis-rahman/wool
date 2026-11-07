import XCTest

@testable import Wool

final class WoolModelContainerTests: XCTestCase {
    func testProductionConfigurationUsesThePrivateWoolCloudKitContainer() {
        let configuration = WoolModelContainer.configuration(isTesting: false)

        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertEqual(configuration.cloudKitContainerIdentifier, "iCloud.com.sparkage.wool")
    }

    func testTestingConfigurationUsesAnIsolatedLocalStoreWithoutCloudKit() {
        let configuration = WoolModelContainer.configuration(isTesting: true)

        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertTrue(configuration.url.lastPathComponent.hasPrefix("WoolUITests-"))
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
    }
}
