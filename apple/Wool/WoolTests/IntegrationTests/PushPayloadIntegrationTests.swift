import XCTest
@testable import Wool

@MainActor
final class PushPayloadIntegrationTests: XCTestCase {
    private var timer: PomodoroTimer!

    override func setUp() {
        super.setUp()
        FocusTimerPersistence.clear()
        timer = PomodoroTimer()
        TimerSyncManager.shared.configure(with: timer)
    }

    override func tearDown() {
        FocusTimerPersistence.clear()
        timer.reset()
        timer = nil
        super.tearDown()
    }

    func testIncomingStateWithNewerTimestampAppliesAllFields() {
        timer.setLastModifiedTimestamp(1_000)
        TimerSyncManager.shared.applyIncomingState([
            "phase": "short_break", "remainingSeconds": 250,
            "isRunning": false, "workDuration": 1_500,
            "breakDuration": 300, "longBreakDuration": 900,
            "autoStartNextSession": true, "shortBreaksCompleted": 2,
            "lastModifiedTimestamp": 1_001.0
        ])

        XCTAssertEqual(timer.phase, .break)
        XCTAssertEqual(timer.remainingSeconds, 250)
        XCTAssertTrue(timer.autoStartNextSession)
        XCTAssertEqual(timer.shortBreaksCompleted, 2)
    }

    func testIncomingStateWithOlderTimestampIsIgnored() {
        timer.setLastModifiedTimestamp(1_000)
        timer.remainingSeconds = 700

        TimerSyncManager.shared.applyIncomingState([
            "phase": "short_break", "remainingSeconds": 250,
            "isRunning": false, "lastModifiedTimestamp": 999.0
        ])

        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remainingSeconds, 700)
    }

    func testEqualTimestampDoesNotOverwriteLocalState() {
        timer.setLastModifiedTimestamp(1_000)
        timer.remainingSeconds = 700

        TimerSyncManager.shared.applyIncomingState([
            "phase": "long_break", "remainingSeconds": 250,
            "isRunning": false, "lastModifiedTimestamp": 1_000.0
        ])

        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remainingSeconds, 700)
    }

    func testAppliedIncomingStatePersistsForRelaunch() {
        timer.setLastModifiedTimestamp(1_000)
        TimerSyncManager.shared.applyIncomingState([
            "phase": "long_break", "remainingSeconds": 850,
            "isRunning": false, "lastModifiedTimestamp": 1_001.0
        ])

        let restored = PomodoroTimer()
        restored.restorePersistedState()
        XCTAssertEqual(restored.phase, .longBreak)
        XCTAssertEqual(restored.remainingSeconds, 850)
    }
}
