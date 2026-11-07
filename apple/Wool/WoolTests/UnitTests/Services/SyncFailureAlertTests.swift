import XCTest
@testable import Wool

@MainActor
final class SyncFailureAlertTests: XCTestCase {
    override func tearDown() {
        SyncFailureAlertManager.shared.dismissAlert()
        super.tearDown()
    }

    func testAlertIsHiddenUntilShown() {
        XCTAssertFalse(SyncFailureAlertManager.shared.isActive)
        XCTAssertEqual(SyncFailureAlertManager.shared.failureCount, 0)
    }

    func testFailuresExposeRetryState() {
        let manager = SyncFailureAlertManager.shared
        manager.showAlert(consecutiveFailures: 3)
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.failureCount, 3)
    }

    func testRetryActionIsStoredAndDismissClearsIt() async {
        let manager = SyncFailureAlertManager.shared
        var retryCount = 0
        manager.showAlert(consecutiveFailures: 3) { retryCount += 1 }
        await manager.retryAction?()
        XCTAssertEqual(retryCount, 1)
        manager.dismissAlert()
        XCTAssertFalse(manager.isActive)
        XCTAssertNil(manager.retryAction)
    }
}
