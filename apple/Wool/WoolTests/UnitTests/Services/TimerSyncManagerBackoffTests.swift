import XCTest
@testable import Wool

@MainActor
final class TimerSyncManagerBackoffTests: XCTestCase {
    func testBackoffUsesBoundedExponentialIntervals() {
        let manager = SyncFailureAlertManager.shared
        XCTAssertEqual(manager.getBackoffInterval(for: 0), 300)
        XCTAssertEqual(manager.getBackoffInterval(for: 1), 30)
        XCTAssertEqual(manager.getBackoffInterval(for: 2), 60)
        XCTAssertEqual(manager.getBackoffInterval(for: 3), 120)
        XCTAssertEqual(manager.getBackoffInterval(for: 4), 300)
        XCTAssertEqual(manager.getBackoffInterval(for: 20), 300)
    }
}
