import XCTest

/// Runs on an iOS Simulator with the debug diagnostics
/// launch environment enabled. It verifies the user-visible support surface.
final class FeatureFlagsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(debugDiagnostics: true)
    }

    private func launch(debugDiagnostics: Bool) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment = debugDiagnostics
            ? [
                "WOOL_UI_TESTING": "1",
                "WOOL_FEATURE_FLAGS_DEBUG": "1"
            ]
            : ["WOOL_UI_TESTING": "1"]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func scrollSettingsUntilVisible(_ element: XCUIElement) {
        for _ in 0..<6 where !element.exists {
            app.swipeUp()
        }
    }

    func testSupportViewShowsAllActiveFeatureFlags() {
        app.buttons["workspace-settings"].tap()

        let featureFlagsLink = app.buttons["Feature Flags"]
        scrollSettingsUntilVisible(featureFlagsLink)
        XCTAssertTrue(featureFlagsLink.waitForExistence(timeout: 5))
        featureFlagsLink.tap()

        XCTAssertTrue(app.navigationBars["Feature Flags"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["features.malayalamVoice"].exists)
        XCTAssertTrue(app.staticTexts["features.gmailIntegration"].exists)
        XCTAssertTrue(app.staticTexts["features.githubProjectsIntegration"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "OFF").count >= 3)
    }

    func testSupportViewIsHiddenWithoutDeveloperToggle() {
        app.terminate()
        launch(debugDiagnostics: false)
        app.buttons["workspace-settings"].tap()

        XCTAssertFalse(app.buttons["Feature Flags"].waitForExistence(timeout: 2))
    }
}
