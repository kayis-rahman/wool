import XCTest

final class iOSTimerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = ["WOOL_UI_TESTING": "1"]

        addUIInterruptionMonitor(withDescription: "System notification permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists {
                allow.tap()
                return true
            }
            let ok = alert.buttons["OK"]
            if ok.exists {
                ok.tap()
                return true
            }
            return false
        }

        app.launch()
        openFocusTab()
    }

    func testFocusAllowsStartingWithoutTaskAndShowsGenericState() {
        XCTAssertTrue(app.buttons["focus-current-task"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["No task selected"].exists)

        let startButton = app.buttons["focus-primary-action"]
        XCTAssertTrue(startButton.exists)
        XCTAssertEqual(startButton.label, "Start focus")

        startButton.tap()
        XCTAssertTrue(app.buttons["focus-primary-action"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["focus-primary-action"].label, "Pause focus")
        XCTAssertFalse(app.buttons["focus-current-task"].isEnabled)

        app.buttons["focus-primary-action"].tap()
        XCTAssertEqual(app.buttons["focus-primary-action"].label, "Resume focus")
    }

    func testFocusSessionSurvivesBackgroundAndForeground() {
        let startButton = app.buttons["focus-primary-action"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 15))
        startButton.tap()
        XCTAssertEqual(startButton.label, "Pause focus")

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.buttons["focus-primary-action"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["focus-primary-action"].label, "Pause focus")
        app.buttons["focus-primary-action"].tap()
    }

    func testTaskPickerExplicitlyAllowsNoTask() {
        let currentTask = app.buttons["focus-current-task"]
        XCTAssertTrue(currentTask.waitForExistence(timeout: 15))
        currentTask.tap()

        let noTask = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'No Task'")).firstMatch
        XCTAssertTrue(noTask.waitForExistence(timeout: 10))
        noTask.tap()

        XCTAssertTrue(app.staticTexts["No task selected"].waitForExistence(timeout: 5))
    }

    private func openFocusTab() {
        let focusTab = app.tabBars.buttons["Focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 15))
        focusTab.tap()
        XCTAssertTrue(app.otherElements["focus-tab-content"].waitForExistence(timeout: 15))
    }
}
