import XCTest

/// Runs on an iOS Simulator. Live OAuth is intentionally
/// excluded; the app injects a deterministic Gmail account/message fixture.
final class GmailIntegrationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_GMAIL_UI_TESTING": "1"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
        app.buttons["workspace-settings"].tap()
    }

    func testGmailFixtureSyncImportsRawInboxItem() {
        XCTAssertTrue(app.staticTexts["UI Gmail Fixture"].waitForExistence(timeout: 5))
        let sync = app.buttons["Sync Now"]
        XCTAssertTrue(sync.exists)
        sync.tap()

        XCTAssertTrue(app.staticTexts["Imported 1 email(s)."].waitForExistence(timeout: 10))
        app.buttons["OK"].tap()
        let inboxTab = app.tabBars.buttons["Inbox"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 5))
        inboxTab.tap()
        let importedTask = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "UI Test Gmail Review"))
            .firstMatch
        XCTAssertTrue(importedTask.waitForExistence(timeout: 10))
    }

    func testGmailFixtureRepeatedSyncDoesNotDuplicateImport() {
        let sync = app.buttons["Sync Now"]
        XCTAssertTrue(sync.waitForExistence(timeout: 5))
        sync.tap()
        XCTAssertTrue(app.staticTexts["Imported 1 email(s)."].waitForExistence(timeout: 10))
        app.buttons["OK"].tap()
        sync.tap()
        XCTAssertTrue(app.staticTexts["Imported 0 email(s)."].waitForExistence(timeout: 10))
    }

    func testDisconnectShowsSafeRetentionConfirmation() {
        let disconnect = app.buttons["Disconnect"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()

        XCTAssertTrue(app.staticTexts["Future email imports will stop. Existing Inbox items will remain."].waitForExistence(timeout: 5))
        let disconnectButtons = app.buttons.matching(identifier: "Disconnect")
        XCTAssertTrue(disconnectButtons.count > 0)
    }
}
