import XCTest
@testable import Wool

@MainActor
final class SetupAppSyncTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FocusTimerPersistence.clear()
        FocusSessionLifecycleStore.clear()
    }

    override func tearDown() {
        FocusTimerPersistence.clear()
        FocusSessionLifecycleStore.clear()
        super.tearDown()
    }

    func testAppLaunchRestoresPersistedTimerBeforeUse() {
        let original = PomodoroTimer(workDuration: 60, breakDuration: 5)
        original.phase = .break
        original.remainingSeconds = 4
        original.autoStartNextSession = true
        original.shortBreaksCompleted = 1
        original.persistState()

        let restored = PomodoroTimer(workDuration: 60, breakDuration: 5)
        restored.restorePersistedState()

        XCTAssertEqual(restored.phase, .break)
        XCTAssertEqual(restored.remainingSeconds, 4)
        XCTAssertTrue(restored.autoStartNextSession)
        XCTAssertEqual(restored.shortBreaksCompleted, 1)
    }

    func testTimerSyncManagerUsesTheConfiguredLocalTimer() {
        let timer = PomodoroTimer()
        TimerSyncManager.shared.configure(with: timer)
        XCTAssertTrue(TimerSyncManager.shared.getTimer() === timer)
    }

    func testPersistedStateIsAvailableAfterRecreation() {
        let sessionID = UUID()
        FocusTimerPersistence.save(FocusTimerSnapshot(
            activeSessionId: sessionID,
            phase: .work,
            remainingSeconds: 42,
            isRunning: false,
            shortBreaksCompleted: 0,
            autoStartNextSession: false,
            currentTaskId: nil,
            taskTitleSnapshot: nil,
            sessionStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accumulatedElapsedSeconds: 18,
            runStartedAt: nil,
            lastReconciledAt: nil,
            endAt: nil,
            savedAt: Date(timeIntervalSince1970: 1_700_000_018)
        ))

        let recreated = PomodoroTimer(workDuration: 60, breakDuration: 5)
        recreated.restorePersistedState()

        XCTAssertEqual(recreated.activeSessionId, sessionID)
        XCTAssertFalse(recreated.isRunning)
        XCTAssertEqual(recreated.remainingSeconds, 42)
        XCTAssertEqual(recreated.accumulatedElapsedSeconds, 18)
    }
}
