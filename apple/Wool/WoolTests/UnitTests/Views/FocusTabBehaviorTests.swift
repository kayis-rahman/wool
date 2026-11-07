import XCTest
@testable import Wool

@MainActor
final class FocusTabBehaviorTests: XCTestCase {
    func testActionTitleReflectsFreshPausedAndRunningStates() {
        XCTAssertEqual(
            FocusTabBehavior.actionTitle(isRunning: false, remainingSeconds: 1500, currentDuration: 1500),
            "Start focus"
        )
        XCTAssertEqual(
            FocusTabBehavior.actionTitle(isRunning: false, remainingSeconds: 1200, currentDuration: 1500),
            "Resume focus"
        )
        XCTAssertEqual(
            FocusTabBehavior.actionTitle(isRunning: true, remainingSeconds: 1200, currentDuration: 1500),
            "Pause focus"
        )
    }

    func testHeadingDistinguishesFocusFromBothBreakPhases() {
        XCTAssertEqual(FocusTabBehavior.heading(for: .work), "What deserves your attention?")
        XCTAssertEqual(FocusTabBehavior.heading(for: .break), "Give yourself a breather")
        XCTAssertEqual(FocusTabBehavior.heading(for: .longBreak), "Give yourself a breather")
    }

    func testPromptExplainsRunningPausedFreshAndBreakStates() {
        XCTAssertEqual(
            FocusTabBehavior.prompt(for: .work, isRunning: true, remainingSeconds: 1200, currentDuration: 1500),
            "Stay with this moment."
        )
        XCTAssertEqual(
            FocusTabBehavior.prompt(for: .work, isRunning: false, remainingSeconds: 1200, currentDuration: 1500),
            "Your session is paused."
        )
        XCTAssertEqual(
            FocusTabBehavior.prompt(for: .work, isRunning: false, remainingSeconds: 1500, currentDuration: 1500),
            "Choose a task, then begin when you’re ready."
        )
        XCTAssertEqual(
            FocusTabBehavior.prompt(for: .break, isRunning: false, remainingSeconds: 300, currentDuration: 300),
            "Step away for a few minutes."
        )
    }

    func testFocusTimeUsesMinutesUntilAnHourThenUsesHoursAndMinutes() {
        XCTAssertEqual(FocusTabBehavior.formattedFocusTime(seconds: 0), "0m")
        XCTAssertEqual(FocusTabBehavior.formattedFocusTime(seconds: 25 * 60), "25m")
        XCTAssertEqual(FocusTabBehavior.formattedFocusTime(seconds: 90 * 60), "1h 30m")
        XCTAssertEqual(FocusTabBehavior.formattedFocusTime(seconds: -60), "0m")
    }

    func testUpNextExcludesCurrentTaskAndLimitsTheStrip() {
        let tasks = (0..<6).map { index in
            TaskItem(title: "Task \(index)", status: .nextAction)
        }

        let result = FocusTabBehavior.upNextTasks(from: tasks, excluding: tasks[1].id, limit: 4)

        XCTAssertEqual(result.map(\.title), ["Task 0", "Task 2", "Task 3", "Task 4"])
    }
}
