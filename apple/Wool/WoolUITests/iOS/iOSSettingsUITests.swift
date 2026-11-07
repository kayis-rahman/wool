import XCTest

final class iOSSettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment = ["WOOL_UI_TESTING": "1"]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func openSettings() {
        app.buttons["workspace-settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testSettingsHubShowsPrimaryDestinations() {
        openSettings()
        XCTAssertTrue(app.buttons["settings-account"].exists)
        XCTAssertTrue(app.buttons["settings-focus"].exists)
        XCTAssertTrue(app.buttons["settings-sound-haptics"].exists)
        XCTAssertTrue(app.buttons["settings-appearance"].exists)
        XCTAssertTrue(app.buttons["settings-support-about"].exists)
        XCTAssertTrue(app.buttons["settings-data-privacy"].exists)
    }

    func testFocusSettingsShowsSafeTimerControls() {
        openSettings()
        app.buttons["settings-focus"].tap()
        XCTAssertTrue(app.navigationBars["Focus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Focus duration"].exists)
        XCTAssertTrue(app.staticTexts["Short break"].exists)
        XCTAssertTrue(app.staticTexts["Long break"].exists)
        XCTAssertTrue(app.switches["settings-auto-start"].exists)
    }

    func testDataPrivacyRequiresConfirmation() {
        openSettings()
        app.buttons["settings-data-privacy"].tap()
        XCTAssertTrue(app.navigationBars["Data & Privacy"].waitForExistence(timeout: 5))
        app.buttons["settings-clear-history"].tap()
        XCTAssertTrue(app.buttons["Clear history"].waitForExistence(timeout: 3))
    }

    func testNotificationsSettingsShowsMasterAndWeeklyReviewToggles() {
        openSettings()
        app.buttons["settings-notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings-notifications-enabled"].exists)
        XCTAssertTrue(app.switches["settings-weekly-review-reminder"].exists)
    }

    func testDisablingNotificationsDisablesWeeklyReviewToggle() {
        openSettings()
        app.buttons["settings-notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))

        let masterToggle = app.switches["settings-notifications-enabled"]
        let weeklyReviewToggle = app.switches["settings-weekly-review-reminder"]
        XCTAssertTrue(masterToggle.waitForExistence(timeout: 5))

        masterToggle.tap()
        let valueWhileDisabled = weeklyReviewToggle.value as? String
        weeklyReviewToggle.tap()
        XCTAssertEqual(weeklyReviewToggle.value as? String, valueWhileDisabled, "Weekly review toggle should not respond to taps while notifications are disabled")

        masterToggle.tap()
        let reenabledToggle = app.switches["settings-weekly-review-reminder"]
        let becameHittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: reenabledToggle)
        XCTAssertEqual(XCTWaiter().wait(for: [becameHittable], timeout: 5), .completed, "Weekly review toggle should become interactive again once notifications are re-enabled")
    }
}
