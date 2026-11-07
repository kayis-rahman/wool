import XCTest

final class WorkspaceUITests: XCTestCase {
    private var app: XCUIApplication!
    // Shared across every launch/relaunch within a single test method so the
    // SwiftData store is stable when a test relaunches mid-test to verify
    // persistence, while still isolating separate test methods from each other.
    private let uiTestStoreID = UUID().uuidString

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID
        ]
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 30))
    }

    func testHomeTaskOpensDetailsAndSaves() throws {
        relaunch(prefilledCaptureTitle: "Email the client today")
        let capture = app.buttons["home-capture-ui-testing"]
        XCTAssertTrue(capture.waitForExistence(timeout: 15))
        capture.tap()

        let titleField = app.textFields["capture-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        XCTAssertEqual(titleField.value as? String, "Email the client today")
        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(saveCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()
        let confirmCapture = app.buttons["Confirm"]
        XCTAssertTrue(confirmCapture.waitForExistence(timeout: 10))
        confirmCapture.tap()

        // "Email the client today" is classified as a next action due today,
        // so it surfaces directly in Home's Today list rather than Inbox.
        // The row's due-date badge joins the title in the combined
        // accessibility label, so match by prefix rather than exact text.
        let taskRowPredicate = NSPredicate(format: "label BEGINSWITH %@", "Email the client today")
        let task = app.buttons.matching(taskRowPredicate).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        task.tap()

        XCTAssertTrue(app.navigationBars["Task details"].waitForExistence(timeout: 5))
        let detailTitle = app.textFields["task-detail-title"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 5))
        app.buttons["task-detail-save"].tap()

        XCTAssertTrue(app.navigationBars["Task details"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(taskRowPredicate).firstMatch.waitForExistence(timeout: 5))
    }

    func testDailyBriefingShowsPositiveEmptyStateOnDevice() throws {
        let briefingButton = app.buttons["daily-briefing-button"]
        XCTAssertTrue(briefingButton.waitForExistence(timeout: 10))
        briefingButton.tap()

        XCTAssertTrue(app.navigationBars["Daily briefing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["All clear"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All clear — nothing is due today."].exists)
    }

    func testTodayBriefingKeepsCaptureAndNamesItsAreaFilter() throws {
        let summary = app.descendants(matching: .any)["today-orientation-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].exists)
        XCTAssertTrue(app.buttons["today-see-all-next-actions"].exists)

        let allAreasFilter = app.buttons["area-filter-all-areas"]
        XCTAssertTrue(allAreasFilter.exists)
        XCTAssertEqual(allAreasFilter.label, "Filter by All areas")
        XCTAssertTrue(app.buttons["area-filter-uncategorized"].exists)
    }

    func testDailyBriefingShowsDueOverdueAndCappedUpNextSections() throws {
        relaunchWithDailyBriefingFixtures()
        app.buttons["daily-briefing-button"].tap()

        XCTAssertTrue(app.navigationBars["Daily briefing"].waitForExistence(timeout: 10))
        for identifier in [
            "daily-briefing-due-today",
            "daily-briefing-overdue",
            "daily-briefing-waiting",
            "daily-briefing-up-next"
        ] {
            let section = app.descendants(matching: .any)
                .matching(identifier: identifier)
                .firstMatch
            XCTAssertTrue(section.waitForExistence(timeout: 5))
        }
        XCTAssertTrue(app.staticTexts["UI Test Briefing Up Next"].exists)
    }

    func testDailyBriefingShowsWaitingCountWhenNothingIsDue() throws {
        relaunchWithDailyBriefingFixtures(waitingOnly: true)
        app.buttons["daily-briefing-button"].tap()

        XCTAssertTrue(app.navigationBars["Daily briefing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Nothing due today, 1 item in Waiting For."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["All clear"].exists)
    }

    func testDailyBriefingShowsAllDayAndTimedCalendarSections() throws {
        relaunchWithDailyBriefingCalendarFixtures()
        app.buttons["daily-briefing-button"].tap()

        let calendarSection = app.descendants(matching: .any)
            .matching(identifier: "daily-briefing-calendar")
            .firstMatch
        XCTAssertTrue(calendarSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Test Team Offsite"].exists)
        XCTAssertTrue(app.staticTexts["Schedule"].exists)
        XCTAssertTrue(app.staticTexts["UI Test Planning"].exists)
    }

    func testEmptyCaptureCannotBeSaved() throws {
        relaunch(prefilledCaptureTitle: "")
        app.buttons["home-capture-ui-testing"].tap()

        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(saveCapture.waitForExistence(timeout: 5))
        XCTAssertFalse(saveCapture.isEnabled)
    }

    func testVoiceCaptureShowsEditableTranscriptBeforeConfirmation() throws {
        relaunchVoiceCaptureFixture(transcript: "Buy groceries from the market")
        app.buttons["home-capture-ui-testing"].tap()

        let mic = app.buttons["capture-voice-mic"]
        XCTAssertTrue(mic.waitForExistence(timeout: 5))
        mic.tap()

        XCTAssertTrue(app.staticTexts["Listening… tap stop when you’re done"].waitForExistence(timeout: 5))
        app.buttons["capture-voice-stop"].tap()

        let title = app.textFields["capture-title-field"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Buy groceries from the market")
        XCTAssertTrue(app.buttons["Save"].isEnabled)
    }

    func testVoiceCaptureCanBeSavedToInboxAfterConfirmation() throws {
        let marker = "Saved voice capture \(UUID().uuidString)"
        relaunchVoiceCaptureFixture(transcript: marker)
        app.buttons["home-capture-ui-testing"].tap()
        app.buttons["capture-voice-mic"].tap()
        XCTAssertTrue(app.buttons["capture-voice-stop"].waitForExistence(timeout: 5))
        app.buttons["capture-voice-stop"].tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(waitForEnabled(save, timeout: 5))
        save.tap()

        let confirm = app.buttons["Confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        app.buttons["capture-category-inbox"].tap()
        confirm.tap()

        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 10))
    }

    func testVoiceCaptureTimeoutOffersTypedFallback() throws {
        relaunchVoiceCaptureFixture(transcript: "")
        app.buttons["home-capture-ui-testing"].tap()
        app.buttons["capture-voice-mic"].tap()

        XCTAssertTrue(app.staticTexts["I didn’t catch that. Try speaking again or type instead."].waitForExistence(timeout: 8))
        let typeInstead = app.buttons["capture-voice-type-instead"]
        XCTAssertTrue(typeInstead.exists)
        typeInstead.tap()

        XCTAssertFalse(app.staticTexts["I didn’t catch that. Try speaking again or type instead."].exists)
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    func testCancellingVoiceCaptureDoesNotCreateAnInboxItem() throws {
        let marker = "Cancelled voice capture \(UUID().uuidString)"
        relaunchVoiceCaptureFixture(transcript: marker)
        app.buttons["home-capture-ui-testing"].tap()
        app.buttons["capture-voice-mic"].tap()
        XCTAssertTrue(app.buttons["capture-voice-stop"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Inbox"].tap()
        XCTAssertFalse(app.staticTexts[marker].waitForExistence(timeout: 3))
    }

    func testWhitespaceOnlyCaptureCannotBeSaved() throws {
        relaunch(prefilledCaptureTitle: "   \t  ")
        app.buttons["home-capture-ui-testing"].tap()

        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(saveCapture.waitForExistence(timeout: 5))
        XCTAssertFalse(saveCapture.isEnabled)
    }

    func testSpecialCharactersEmojiAndNonEnglishCaptureAreVisibleInInbox() throws {
        captureAndAssertInbox("Fix bug #123 @ 50% done!", forceInbox: true)
        relaunch(prefilledCaptureTitle: "Buy 🥛 and 🍞")
        captureAndAssertInbox("Buy 🥛 and 🍞", forceInbox: true)
        relaunch(prefilledCaptureTitle: "Acheter du lait pour demain")
        captureAndAssertInbox("Acheter du lait pour demain", forceInbox: true)
    }

    func testLongCaptureIsAcceptedAndStoredInInbox() throws {
        let title = String(repeating: "Review the project notes and decide the next step. ", count: 15)
        captureAndAssertInbox(title, forceInbox: true)

        XCTAssertTrue(app.staticTexts["To process"].waitForExistence(timeout: 5))
    }

    func testDuplicateRapidCapturesCreateTwoInboxItems() throws {
        let title = "Test duplicate capture"
        relaunch(prefilledCaptureTitle: title)
        captureAndAssertInbox(title)
        app.buttons["inbox-capture-button"].tap()
        confirmPrefilledCapture(title)

        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", title)).count, 2)
    }

    func testTenSequentialCapturesAreNotDropped() throws {
        let title = "Rapid capture"
        relaunch(prefilledCaptureTitle: title)
        captureAndAssertInbox(title)
        for _ in 1...9 {
            app.buttons["inbox-capture-button"].tap()
            confirmPrefilledCapture(title)
        }

        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", title)).count, 10)
    }

    func testCaptureDuringWeeklyReviewRemainsInInbox() throws {
        let title = "Capture while in progress"
        relaunch(prefilledCaptureTitle: title)
        openReviewTab()
        XCTAssertTrue(app.buttons["start-weekly-review"].waitForExistence(timeout: 5))
        app.buttons["start-weekly-review"].tap()
        XCTAssertTrue(app.staticTexts["Collect loose ends"].waitForExistence(timeout: 5))

        app.buttons["Today"].tap()
        app.buttons["home-capture-ui-testing"].tap()
        confirmPrefilledCapture(title)
        app.tabBars.buttons["Inbox"].tap()

        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Review"].exists)
    }

    func testUnsubmittedCaptureDoesNotCreatePartialItemAfterRelaunch() throws {
        let title = "Draft that should not persist"
        relaunch(prefilledCaptureTitle: title)
        app.buttons["home-capture-ui-testing"].tap()
        XCTAssertTrue(app.textFields["capture-title-field"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_CAPTURE_TITLE": title
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Inbox"].tap()

        XCTAssertFalse(app.staticTexts[title].exists)
    }

    func testInboxCaptureAppearsInToProcessList() throws {
        relaunch(prefilledCaptureTitle: "Remember the garden lights")
        let inboxTab = app.tabBars.buttons["Inbox"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 15))
        inboxTab.tap()

        let capture = app.buttons["inbox-capture-button"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()

        let titleField = app.textFields["capture-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        XCTAssertEqual(titleField.value as? String, "Remember the garden lights")
        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(saveCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()
        XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 10))
        app.buttons["Confirm"].tap()

        XCTAssertTrue(app.staticTexts["Remember the garden lights"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["To process"].exists)
    }

    func testCaptureShowsEditableConfirmationWithAllCategories() throws {
        relaunch(prefilledCaptureTitle: "Call dentist Tuesday")
        app.buttons["home-capture-ui-testing"].tap()

        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(saveCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()

        XCTAssertTrue(app.navigationBars["Confirm capture"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["capture-category-inbox"].exists)
        XCTAssertTrue(app.buttons["capture-category-nextAction"].exists)
        XCTAssertTrue(app.buttons["capture-category-waitingFor"].exists)
        XCTAssertTrue(app.buttons["capture-category-somedayMaybe"].exists)
        XCTAssertTrue(app.textFields["capture-confirmation-title"].exists)

        app.buttons["capture-category-waitingFor"].tap()
        app.buttons["Confirm"].tap()
    }

    func testCancellingConfirmationLeavesCaptureInInbox() throws {
        relaunch(prefilledCaptureTitle: "Book dentist")
        app.buttons["home-capture-ui-testing"].tap()

        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["Book dentist"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["To process"].exists)
    }

    func testInboxSearchSurfaceIsAccessible() throws {
        relaunch(prefilledCaptureTitle: "A searchable capture")
        let inboxTab = app.buttons["Inbox"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 15))
        inboxTab.tap()

        let searchButton = app.buttons["inbox-search-button"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()

        let searchField = app.textFields["Search captures"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        XCTAssertTrue(searchField.isHittable)
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func captureAndAssertInbox(_ title: String, forceInbox: Bool = false) {
        relaunch(prefilledCaptureTitle: title)
        app.buttons["home-capture-ui-testing"].tap()
        confirmPrefilledCapture(title, status: forceInbox ? "capture-category-inbox" : nil)
        app.tabBars.buttons["Inbox"].tap()
        let persistedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let importedCapture = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", persistedTitle))
            .firstMatch
        XCTAssertTrue(importedCapture.waitForExistence(timeout: 10))
    }

    private func confirmPrefilledCapture(_ title: String, status: String? = nil) {
        let titleField = app.textFields["capture-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertEqual(titleField.value as? String, title)
        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()
        let confirmCapture = app.buttons["Confirm"]
        XCTAssertTrue(confirmCapture.waitForExistence(timeout: 10))
        if let status {
            app.buttons[status].tap()
        }
        confirmCapture.tap()
    }

    private func relaunch(prefilledCaptureTitle: String) {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_CAPTURE_TITLE": prefilledCaptureTitle
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func relaunchVoiceCaptureFixture(transcript: String) {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_VOICE_TRANSCRIPT": transcript
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func relaunchWithProjectAndAreaFixtures() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_SEED_PROJECTS_AREAS": "1"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func relaunchWithStaleReviewFixtures() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_SEED_WEEKLY_REVIEW_STALE": "1"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func relaunchWithDailyBriefingFixtures(waitingOnly: Bool = false) {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        var environment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_SEED_DAILY_BRIEFING": "1",
            "WOOL_UI_TEST_DISABLE_AI": "1"
        ]
        if waitingOnly {
            environment["WOOL_UI_TEST_DAILY_BRIEFING_WAITING_ONLY"] = "1"
        }
        app.launchEnvironment = environment
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    private func relaunchWithDailyBriefingCalendarFixtures() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID,
            "WOOL_UI_TEST_SEED_DAILY_BRIEFING": "1",
            "WOOL_UI_TEST_SEED_DAILY_BRIEFING_CALENDAR": "1",
            "WOOL_UI_TEST_DISABLE_AI": "1"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
    }

    // The step container and its Complete/Skip buttons all report the
    // container's "weekly-review-step-N" accessibility identifier on device
    // (the buttons' own identifiers are not surfaced), so steps must be
    // located by identifier plus visible label rather than a per-button id.
    private func reviewStepButton(_ index: Int, label: String) -> XCUIElement {
        app.buttons["complete-review-step-\(index)"]
    }

    private func openReviewTab() {
        let reviewTab = app.tabBars.buttons["Review"]
        if reviewTab.waitForExistence(timeout: 3) {
            reviewTab.tap()
            return
        }

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 12))
        moreTab.tap()

        let reviewRow = app.staticTexts["Review"].firstMatch
        XCTAssertTrue(reviewRow.waitForExistence(timeout: 5))
        reviewRow.tap()
    }

    func testInboxTriageButtonIsPresentAndAccessible() throws {
        let inboxTab = app.tabBars.buttons["Inbox"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 15))
        inboxTab.tap()

        let triageButton = app.buttons["inbox-triage-button"]
        XCTAssertTrue(triageButton.waitForExistence(timeout: 5))
        XCTAssertEqual(triageButton.label, "Triage")
    }

    func testTriageShowsFutureNextActionInResultsAndList() throws {
        let title = "Email the client tomorrow about the work plan"
        relaunch(prefilledCaptureTitle: title)
        app.tabBars.buttons["Inbox"].tap()
        app.buttons["inbox-capture-button"].tap()

        let titleField = app.textFields["capture-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertEqual(titleField.value as? String, title)
        let saveCapture = app.buttons["Save"]
        XCTAssertTrue(waitForEnabled(saveCapture, timeout: 5))
        saveCapture.tap()
        XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 10))
        // "Email...tomorrow" auto-classifies as a next action due tomorrow, which
        // would leave Inbox entirely. Force it back to Inbox so triage has
        // something to sort.
        app.buttons["capture-category-inbox"].tap()
        app.buttons["Confirm"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))

        let triageButton = app.buttons["inbox-triage-button"]
        XCTAssertTrue(triageButton.waitForExistence(timeout: 5))
        triageButton.tap()

        XCTAssertTrue(app.navigationBars["Sorted for you"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Next Action"].exists)
        XCTAssertTrue(app.staticTexts[title].exists)
        let allLists = app.buttons["triage-results-all-lists"]
        XCTAssertTrue(allLists.waitForExistence(timeout: 5))
        allLists.tap()

        XCTAssertTrue(app.navigationBars["Next Action"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Next Action"].exists)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    func testWeeklyReviewStartsWithTheStructuredChecklist() throws {
        openReviewTab()

        XCTAssertTrue(app.navigationBars["Weekly Review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WEEKLY RESET"].exists)
        XCTAssertTrue(app.staticTexts["Make space for the week ahead."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["review-landing"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Reviews"].exists)
        XCTAssertTrue(app.staticTexts["Week streak"].exists)
        XCTAssertTrue(app.staticTexts["Inbox"].exists)
        XCTAssertTrue(app.staticTexts["Projects"].exists)
        XCTAssertTrue(app.staticTexts["Waiting"].exists)
        let startReview = app.buttons["Start weekly review"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 5))
        startReview.tap()

        XCTAssertTrue(app.staticTexts["Collect loose ends"].waitForExistence(timeout: 5))
        for index in 0...5 {
            XCTAssertTrue(app.buttons["review-step-navigator-\(index)"].exists)
        }
        XCTAssertFalse(app.buttons["weekly-review-step-1"].exists)
    }

    func testWeeklyReviewCanSkipEveryStepAndShowsPartialCompletion() throws {
        openReviewTab()
        let startReview = app.buttons["start-weekly-review"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 5))
        startReview.tap()

        // The stale-items step auto-completes when there is nothing stale, so
        // only the remaining five steps expose an enabled Skip control.
        for index in 0..<5 {
            let skip = app.buttons
                .matching(NSPredicate(format: "label == 'Skip' AND isEnabled == true"))
                .firstMatch
            XCTAssertTrue(
                skip.waitForExistence(timeout: 5),
                "Missing enabled Skip control for Weekly Review step \(index)"
            )
            skip.tap()
        }

        XCTAssertTrue(app.staticTexts["Partial review"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["review-completion-summary"].firstMatch.exists)
        let startNew = app.buttons["start-new-weekly-review"]
        XCTAssertTrue(startNew.waitForExistence(timeout: 10))

        // Tapping "Start a new review" must begin a genuinely fresh review,
        // not reopen the one just finished (step 0 back to "Complete").
        startNew.tap()
        XCTAssertTrue(app.staticTexts["Collect loose ends"].waitForExistence(timeout: 5))
    }

    func testWeeklyReviewAutomaticallyCompletesEmptyStaleStep() throws {
        openReviewTab()
        let startReview = app.buttons["start-weekly-review"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 5))
        startReview.tap()

        app.buttons["review-step-navigator-2"].tap()
        XCTAssertTrue(app.staticTexts["Nothing stale"].waitForExistence(timeout: 5))
    }

    func testWeeklyReviewResumesAfterAppRelaunch() throws {
        openReviewTab()
        let startReview = app.buttons["start-weekly-review"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 5))
        startReview.tap()
        app.buttons.matching(NSPredicate(format: "label == 'Complete'")).firstMatch.tap()

        app.terminate()
        app.launchArguments = ["-ui-testing", "-focus-test-reset"]
        app.launchEnvironment = [
            "WOOL_UI_TESTING": "1",
            "WOOL_UI_TEST_STORE_ID": uiTestStoreID
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-capture-ui-testing"].waitForExistence(timeout: 15))
        openReviewTab()

        let completedStep = app.buttons["review-step-navigator-0"]
        XCTAssertTrue(completedStep.waitForExistence(timeout: 5))
        XCTAssertEqual(completedStep.value as? String, "Complete")
        XCTAssertTrue(app.buttons["review-step-navigator-1"].isEnabled)
    }

    func testWeeklyReviewWithUnresolvedStaleItemFinishesPartial() throws {
        relaunchWithStaleReviewFixtures()
        openReviewTab()
        app.buttons["start-weekly-review"].tap()

        for index in 0...5 {
            let complete = app.buttons.matching(NSPredicate(format: "label == 'Complete'")).firstMatch
            XCTAssertTrue(complete.waitForExistence(timeout: 5))
            if index == 2 {
                XCTAssertTrue(app.staticTexts["UI Test Stale Review Item"].exists)
            }
            complete.tap()
        }

        XCTAssertTrue(app.staticTexts["Partial review"].waitForExistence(timeout: 5))
    }

    func testProjectCompletionIsBlockedWhileOpenActionsRemain() throws {
        relaunchWithProjectAndAreaFixtures()
        openReviewTab()
        app.buttons["start-weekly-review"].tap()

        app.tabBars.buttons["Projects"].tap()
        app.staticTexts["UI Test Project"].tap()
        let completion = app.buttons["project-completion-action"]
        XCTAssertTrue(completion.waitForExistence(timeout: 5))
        completion.tap()
        XCTAssertTrue(app.alerts["Open actions remain"].waitForExistence(timeout: 5))
    }

    func testProjectCanBeArchivedAndRestoredWithoutLosingLinkedActions() throws {
        relaunchWithProjectAndAreaFixtures()
        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Project"].tap()

        let actionsMenu = app.buttons["project-actions-menu"]
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 5))
        actionsMenu.tap()
        let archiveAction = app.buttons["archive-project"]
        XCTAssertTrue(archiveAction.waitForExistence(timeout: 5))
        archiveAction.tap()

        let archiveAlert = app.alerts["Archive project?"]
        XCTAssertTrue(archiveAlert.waitForExistence(timeout: 5))
        archiveAlert.buttons["Archive project"].tap()

        app.tabBars.buttons["Projects"].tap()
        app.buttons["workspace-filter-archived"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Project"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Project Next Action"].waitForExistence(timeout: 5))

        app.buttons["project-actions-menu"].tap()
        let restoreAction = app.buttons["restore-project"]
        XCTAssertTrue(restoreAction.waitForExistence(timeout: 5))
        restoreAction.tap()

        app.tabBars.buttons["Projects"].tap()
        app.buttons["workspace-filter-active"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 10))
    }

    func testEmptyProjectArchiveShowsConfirmation() throws {
        relaunchWithProjectAndAreaFixtures()
        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Empty Project"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Empty Project"].tap()

        app.buttons["project-actions-menu"].tap()
        app.buttons["archive-project"].tap()

        let archiveAlert = app.alerts["Archive project?"]
        XCTAssertTrue(archiveAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(archiveAlert.staticTexts["This empty project will be hidden until you restore it."].exists)
        archiveAlert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["UI Test Empty Project"].exists)
    }

    func testProjectsSurfaceCanCreateAndOpenAnOutcome() throws {
        relaunchWithProjectAndAreaFixtures()
        let projectsTab = app.tabBars.buttons["Projects"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 15))
        projectsTab.tap()

        XCTAssertTrue(app.staticTexts["OUTCOMES"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Turn multi-step commitments into clear, finishable outcomes."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["project-portfolio-header"].firstMatch.exists)
        for identifier in [
            "project-portfolio-metric-active",
            "project-portfolio-metric-moving",
            "project-portfolio-metric-needs-action"
        ] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.exists)
        }
        XCTAssertTrue(app.staticTexts["1 project needs a next action"].exists)
        XCTAssertTrue(app.staticTexts["Next · UI Test Project Next Action"].exists)
        XCTAssertTrue(app.staticTexts["Add a clear next action"].exists)

        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 5))
        app.staticTexts["UI Test Project"].tap()
        XCTAssertTrue(app.navigationBars["UI Test Project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["project-detail-outcome"].firstMatch.exists)
    }

    func testAreasSurfaceCanCreateAndOpenAnOngoingResponsibility() throws {
        relaunchWithProjectAndAreaFixtures()
        openReviewTab()
        XCTAssertTrue(app.buttons["review-areas-overview"].waitForExistence(timeout: 10))
        app.buttons["review-areas-overview"].tap()
        XCTAssertTrue(app.navigationBars["Areas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Test Area"].waitForExistence(timeout: 5))
        app.staticTexts["UI Test Area"].tap()
        XCTAssertTrue(app.navigationBars["UI Test Area"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Responsibility"].exists)
    }

    func testProjectsSurfaceCanSwitchToCompletedFilter() throws {
        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.buttons["workspace-filter-active"].waitForExistence(timeout: 10))
        app.buttons["workspace-filter-completed"].tap()
        XCTAssertTrue(app.buttons["workspace-filter-completed"].exists)
    }

    func testEmptyProjectsCreateActionIsReachableAboveTabBar() throws {
        let projectsTab = app.tabBars.buttons["Projects"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 10))
        projectsTab.tap()

        let createProject = app.buttons["empty-add-project"]
        XCTAssertTrue(createProject.waitForExistence(timeout: 10))
        XCTAssertTrue(createProject.isHittable, "The create-project action must remain tappable.")
        XCTAssertFalse(
            createProject.frame.intersects(app.tabBars.firstMatch.frame),
            "The create-project action must remain visually clear of the floating tab bar."
        )
    }

    func testProjectDetailShowsOnlyItsLinkedActionsAndProgress() throws {
        relaunchWithProjectAndAreaFixtures()
        app.tabBars.buttons["Projects"].tap()

        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Project"].tap()

        XCTAssertTrue(app.navigationBars["UI Test Project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["project-detail-outcome"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["project-detail-next-action"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["project-detail-open-actions"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["project-detail-completed-actions"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["UI Test Project Next Action"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Test Project Completed Action"].exists)
        XCTAssertFalse(app.staticTexts["UI Test Other Area Action"].exists)
        let progress = app.descendants(matching: .any)["project-detail-progress"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
    }

    func testProjectDetailCanAddAConcreteNextAction() throws {
        relaunchWithProjectAndAreaFixtures()
        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Project"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Project"].tap()

        app.swipeUp()
        let addAction = app.buttons["Add action"]
        XCTAssertTrue(addAction.waitForExistence(timeout: 5))
        addAction.tap()

        XCTAssertTrue(app.navigationBars["Add action"].waitForExistence(timeout: 5))
        let title = "UI Test Added Project Action"
        let titleField = app.textFields["new-project-action-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let save = app.buttons["save-project-action"]
        XCTAssertTrue(waitForEnabled(save, timeout: 5))
        save.tap()

        XCTAssertTrue(app.navigationBars["Add action"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    func testAreaDetailShowsOnlyItsOpenLinkedActions() throws {
        relaunchWithProjectAndAreaFixtures()
        openReviewTab()
        XCTAssertTrue(app.buttons["review-areas-overview"].waitForExistence(timeout: 10))
        app.buttons["review-areas-overview"].tap()

        XCTAssertTrue(app.staticTexts["UI Test Area"].waitForExistence(timeout: 10))
        app.staticTexts["UI Test Area"].tap()

        XCTAssertTrue(app.navigationBars["UI Test Area"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Test Project Next Action"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["UI Test Project Completed Action"].exists)
        XCTAssertFalse(app.staticTexts["UI Test Other Area Action"].exists)
    }

    func testAreaFiltersShowUncategorizedAndRejectDuplicateNames() throws {
        relaunchWithProjectAndAreaFixtures()
        openReviewTab()
        let areasOverview = app.buttons["review-areas-overview"]
        XCTAssertTrue(areasOverview.waitForExistence(timeout: 10))
        areasOverview.tap()

        let addArea = app.buttons["add-area"]
        XCTAssertTrue(addArea.waitForExistence(timeout: 5))
        addArea.tap()
        let name = app.textFields["new-area-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI Test Area")
        app.buttons["Create"].tap()

        XCTAssertTrue(app.alerts["Area not created"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["An Area with this name already exists."].exists)
        app.buttons["OK"].tap()
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Today"].tap()
        let uncategorized = app.buttons["area-filter-uncategorized"]
        XCTAssertTrue(uncategorized.waitForExistence(timeout: 10))
        uncategorized.tap()
        XCTAssertTrue(app.buttons["area-filter-all-areas"].exists)
    }

    func testDeletingAreaMovesItsTaskToUncategorized() throws {
        relaunchWithProjectAndAreaFixtures()
        openReviewTab()
        app.buttons["review-areas-overview"].tap()

        let otherArea = app.staticTexts["UI Test Other Area"]
        XCTAssertTrue(otherArea.waitForExistence(timeout: 10))
        otherArea.swipeLeft()
        let deleteButton = app.buttons["delete-area-ui-test-other-area"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(otherArea.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Today"].tap()
        app.buttons["area-filter-uncategorized"].tap()
        // Home's task row is a NavigationLink whose text children collapse into
        // a single accessibility element that also announces capture metadata.
        let uncategorizedTask = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "UI Test Other Area Action")
        ).firstMatch
        XCTAssertTrue(uncategorizedTask.waitForExistence(timeout: 10))
    }

    func testWorkspaceUsesFiveWorkflowTabsWithFocusLastAndPreservesTimerSurface() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let expectedOrder = ["Today", "Inbox", "Projects", "Review", "Focus"]
        for label in expectedOrder {
            XCTAssertTrue(tabBar.buttons[label].exists, "Missing workflow tab: \(label)")
        }
        XCTAssertEqual(
            tabBar.buttons.allElementsBoundByIndex.map(\.label),
            expectedOrder,
            "The workflow tabs should keep Focus in the final position"
        )
        XCTAssertFalse(tabBar.buttons["Areas"].exists)
        XCTAssertFalse(tabBar.buttons["Profile"].exists)

        tabBar.buttons["Focus"].tap()
        XCTAssertTrue(app.navigationBars["Focus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["focus-timer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["focus-primary-action"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["What deserves your attention?"].exists)
        XCTAssertTrue(app.buttons["focus-current-task"].exists)
    }

    func testFocusOptionsExposeTaskSelectionAndResetWithoutCrowdingTheSurface() throws {
        app.tabBars.buttons["Focus"].tap()

        let options = app.buttons["Focus options"]
        XCTAssertTrue(options.waitForExistence(timeout: 10))
        options.tap()

        XCTAssertTrue(app.buttons["Select task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reset timer"].exists)
    }

    func testFocusTaskPickerCanOpenAndDismissWithNoTaskSelected() throws {
        app.tabBars.buttons["Focus"].tap()
        app.buttons["focus-current-task"].tap()

        XCTAssertTrue(app.navigationBars["Select Task"].waitForExistence(timeout: 10))
        // The row's trailing "Clear selection" caption joins the title in the
        // combined accessibility label, so match by prefix rather than exact text.
        let noTaskPredicate = NSPredicate(format: "label BEGINSWITH %@", "No Task")
        XCTAssertTrue(app.buttons.matching(noTaskPredicate).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Focus"].waitForExistence(timeout: 5))
    }
}
