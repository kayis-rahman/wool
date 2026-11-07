import XCTest
@testable import Wool

@MainActor
final class TimerSyncManagerQueueTests: XCTestCase {
    private var timer: PomodoroTimer!

    override func setUp() {
        super.setUp()
        timer = PomodoroTimer(workDuration: 60, breakDuration: 5)
        TimerSyncManager.shared.configure(with: timer)
    }

    override func tearDown() {
        timer.reset()
        timer = nil
        super.tearDown()
    }

    func testStartAndPauseActionsMutateLocalTimer() async {
        await TimerSyncManager.shared.syncTimerAction(.start)
        XCTAssertTrue(timer.isRunning)
        await TimerSyncManager.shared.syncTimerAction(.pause)
        XCTAssertFalse(timer.isRunning)
    }

    func testResetActionClearsActiveSession() async {
        await TimerSyncManager.shared.syncTimerAction(.start)
        await TimerSyncManager.shared.syncTimerAction(.reset)
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.activeSessionId)
        XCTAssertEqual(timer.phase, .work)
    }

    func testStaleWatchStateIsIgnored() {
        timer.setLastModifiedTimestamp(2_000)
        timer.remainingSeconds = 42
        TimerSyncManager.shared.applyIncomingState([
            "phase": "short_break", "remainingSeconds": 5,
            "isRunning": false, "lastModifiedTimestamp": 1_999.0
        ])
        XCTAssertEqual(timer.remainingSeconds, 42)
        XCTAssertEqual(timer.phase, .work)
    }

    func testNewerWatchStateIsAppliedAndPersisted() {
        timer.setLastModifiedTimestamp(2_000)
        TimerSyncManager.shared.applyIncomingState([
            "phase": "short_break", "remainingSeconds": 5,
            "isRunning": false, "lastModifiedTimestamp": 2_001.0
        ])
        XCTAssertEqual(timer.phase, .break)
        XCTAssertEqual(timer.remainingSeconds, 5)
        XCTAssertEqual(FocusTimerPersistence.load()?.phase, .break)
    }
}
