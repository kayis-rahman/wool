import XCTest
@testable import Wool

@MainActor
final class PomodoroTimerDurationTests: XCTestCase {

    private var timer: PomodoroTimer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        timer = PomodoroTimer()
    }

    override func tearDownWithError() throws {
        timer = nil
        try super.tearDownWithError()
    }

    // MARK: - Default Durations

    func testDefaultWorkDuration() async {
        XCTAssertEqual(timer.workDuration, 25 * 60)
    }

    func testDefaultBreakDuration() async {
        XCTAssertEqual(timer.breakDuration, 5 * 60)
    }

    func testDefaultLongBreakDuration() async {
        XCTAssertEqual(timer.longBreakDuration, 15 * 60)
    }

    // MARK: - updateDurations

    func testUpdateDurationsChangesValues() async {
        timer.updateDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 20)

        XCTAssertEqual(timer.workDuration, 50 * 60)
        XCTAssertEqual(timer.breakDuration, 10 * 60)
        XCTAssertEqual(timer.longBreakDuration, 20 * 60)
    }

    func testUpdateDurationsResetsTimer() async {
        timer.start()
        timer.updateDurations(workMinutes: 30, shortBreakMinutes: 5, longBreakMinutes: 15)

        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.shortBreaksCompleted, 0)
    }

    // MARK: - Progress Edge Cases

    func testProgressAtStart() async {
        XCTAssertEqual(timer.progress, 0)
    }

    func testProgressAtEnd() async {
        timer.remainingSeconds = 0

        XCTAssertEqual(timer.progress, 1, accuracy: 0.01)
    }

    func testProgressNegativeClamped() async {
        timer.remainingSeconds = timer.workDuration + 100

        XCTAssertGreaterThanOrEqual(timer.progress, 0)
    }

    // MARK: - Cycle Size

    func testCycleSizeIsFour() async {
        XCTAssertEqual(timer.cycleSize, 4)
    }
}
