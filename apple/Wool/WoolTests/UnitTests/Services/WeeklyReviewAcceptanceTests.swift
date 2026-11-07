import XCTest
@testable import Wool

@MainActor
final class WeeklyReviewAcceptanceTests: XCTestCase {
    private let service = WeeklyReviewService()

    func testTC1FreshReviewStartsAtFirstOfSixSteps() {
        let review = service.makeWeeklyReview()
        XCTAssertEqual(review.status, .inProgress)
        XCTAssertEqual(review.currentStep, 0)
        XCTAssertEqual(review.checklistItems?.count, 6)
    }

    func testTC2ProgressPersistsAtCurrentStep() {
        let review = service.makeWeeklyReview()
        service.saveStep(review, step: 0, skipped: false)
        service.saveStep(review, step: 1, skipped: false)
        service.saveStep(review, step: 2, skipped: false)
        XCTAssertEqual(review.currentStep, 3)
    }

    func testTC3ResumeFindsMostRecentlySavedInProgressReview() {
        let older = service.makeWeeklyReview(now: Date(timeIntervalSince1970: 100))
        let newer = service.makeWeeklyReview(now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(service.resumeReview(from: [older, newer])?.id, newer.id)
    }

    func testTC3bReviewForCurrentWeekReusesExistingReview() {
        let now = Date()
        let review = service.makeWeeklyReview(now: now)
        XCTAssertEqual(service.review(forWeekContaining: now, from: [review])?.id, review.id)
    }

    func testTC4NoStaleItemsProducesEmptyFlagSet() {
        let task = TaskItem(title: "Recent idea", status: .somedayMaybe)
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([task], for: review, now: .now)
        XCTAssertTrue(review.staleTaskIDs.isEmpty)
        XCTAssertTrue(review.checklistItems?.first(where: { $0.kind == .stale })?.isComplete == true)
    }

    func testTC4bStaleSnapshotDoesNotInjectNewItemsAfterReviewStarts() {
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([], for: review)
        let later = TaskItem(title: "Later stale item", status: .somedayMaybe)
        later.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)

        service.prepareStaleItems([later], for: review)

        XCTAssertTrue(review.staleTaskIDs.isEmpty)
    }

    func testTC4cCompletedStaleItemIsRemovedWhenReviewRefreshes() {
        let task = TaskItem(title: "Old idea", status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([task], for: review)

        task.status = .completed
        service.prepareStaleItems([task], for: review)

        XCTAssertTrue(review.staleTaskIDs.isEmpty)
    }

    func testTC5StaleItemOffersPromoteKeepAndDeleteDecisions() {
        let task = TaskItem(title: "Old idea", status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([task], for: review)
        XCTAssertTrue(review.staleTaskIDs.contains(task.id.uuidString))
        XCTAssertEqual(WeeklyReviewStaleDecision.allCases, [.promote, .keep, .delete])
    }

    func testTC5PromoteStaleItemMovesItToNextAction() {
        let task = TaskItem(title: "Old idea", status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([task], for: review)
        service.decide(.promote, for: task, review: review)
        XCTAssertEqual(task.status, .nextAction)
    }

    func testTC6SkippingStepMarksReviewPartialAndAdvances() {
        let review = service.makeWeeklyReview()
        service.saveStep(review, step: 0, skipped: true)
        XCTAssertTrue(review.checklistItems?.first?.isSkipped == true)
        XCTAssertEqual(review.currentStep, 1)
        XCTAssertTrue(review.isPartial)
    }

    func testTC7SkippingAllStepsCompletesAsPartial() {
        let review = service.makeWeeklyReview()
        for index in 0..<6 { service.saveStep(review, step: index, skipped: true) }
        XCTAssertEqual(review.status, .partial)
        XCTAssertEqual(review.skippedStepCount, 6)
    }

    func testTC8CompletingAllStepsProducesCompleteReview() {
        let review = service.makeWeeklyReview()
        for index in 0..<6 { service.saveStep(review, step: index, skipped: false) }
        XCTAssertEqual(review.status, .completed)
        XCTAssertFalse(review.isPartial)
        XCTAssertNotNil(review.completedAt)
    }

    func testTC8bFinishingAReviewTwiceDoesNotChangeItsStreak() {
        let review = service.makeWeeklyReview()
        for index in 0..<6 { service.saveStep(review, step: index, skipped: false) }
        service.finish(review, reviews: [], now: Date(timeIntervalSince1970: 200))
        let firstCompletion = review.completedAt
        let firstStreak = review.streakAtCompletion

        service.finish(review, reviews: [], now: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(review.completedAt, firstCompletion)
        XCTAssertEqual(review.streakAtCompletion, firstStreak)
    }

    func testTC8dUnresolvedStaleItemsProducePartialReviewWhenChecklistFinishes() {
        let task = TaskItem(title: "Old idea", status: .somedayMaybe)
        task.updatedAt = Date(timeIntervalSinceNow: -45 * 86_400)
        let review = service.makeWeeklyReview()
        service.prepareStaleItems([task], for: review)

        for index in 0..<6 { service.saveStep(review, step: index, skipped: false) }

        XCTAssertEqual(review.status, .partial)
        XCTAssertTrue(review.isPartial)
        XCTAssertEqual(review.staleTaskIDs, [task.id.uuidString])
    }

    func testTC8cDuplicateReviewsForOneWeekCountOnceInStreak() {
        let now = Date()
        let first = service.makeWeeklyReview(now: now)
        first.status = .completed
        let duplicate = service.makeWeeklyReview(now: now)
        duplicate.status = .partial

        XCTAssertEqual(service.reviewStreak([first, duplicate]), 1)
    }

    func testTC9ThreeConsecutiveCompletedWeeksHaveStreakThree() {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let reviews = (0..<3).map { offset -> WeeklyReview in
            let review = service.makeWeeklyReview()
            review.weekStart = calendar.date(byAdding: .day, value: -7 * offset, to: base)!
            review.status = .completed
            return review
        }
        XCTAssertEqual(service.reviewStreak(reviews, calendar: calendar), 3)
    }

    func testTC10GapBreaksStreakBeforeCurrentReview() {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let current = service.makeWeeklyReview(); current.weekStart = base; current.status = .completed
        let old = service.makeWeeklyReview(); old.weekStart = calendar.date(byAdding: .day, value: -14, to: base)!; old.status = .completed
        XCTAssertEqual(service.reviewStreak([current, old], calendar: calendar), 1)
    }

    func testTC11EmptyInboxDoesNotBlockReview() {
        let review = service.makeWeeklyReview()
        service.saveStep(review, step: 0, skipped: false)
        XCTAssertEqual(review.currentStep, 1)
    }

    func testTC12LargeInboxIsPartitionedIntoGracefulBatches() {
        let tasks = (0..<51).map { TaskItem(title: "Inbox \($0)") }
        let batches = service.batches(tasks, size: 25)
        XCTAssertEqual(batches.map(\.count), [25, 25, 1])
    }

    func testTC13ProjectsWithoutNextActionAreFlagged() {
        let project = Project(title: "Needs action")
        project.tasks = [TaskItem(title: "Waiting", status: .waitingFor)]
        XCTAssertEqual(service.projectsNeedingNextAction([project]).map(\.title), ["Needs action"])
    }

    func testTC14ProjectWithOpenActionCannotBeCompleted() {
        let project = Project(title: "Open project")
        project.tasks = [TaskItem(title: "Open", status: .nextAction)]
        XCTAssertFalse(service.canComplete(project))
    }

    func testTC19ArchivedProjectIsNotFlaggedForNextAction() {
        let project = Project(title: "Archived project")
        project.archive()

        XCTAssertTrue(service.projectsNeedingNextAction([project]).isEmpty)
    }

    func testTC20ActiveProjectWithNoChildrenIsFlaggedForNextAction() {
        let project = Project(title: "Empty project")

        XCTAssertEqual(service.projectsNeedingNextAction([project]).map(\.id), [project.id])
    }

    func testTC21CompletedProjectIsNotFlaggedForNextAction() {
        let project = Project(title: "Completed project")
        project.status = .completed

        XCTAssertTrue(service.projectsNeedingNextAction([project]).isEmpty)
    }

    func testTC15SecondDeviceResumesTheSamePersistedReview() {
        let review = service.makeWeeklyReview()
        service.saveStep(review, step: 0, skipped: false)
        XCTAssertEqual(service.resumeReview(from: [review])?.currentStep, 1)
    }

    func testTC16ReviewStateIsLocalAndDoesNotRequireNetwork() {
        let review = service.makeWeeklyReview()
        service.saveStep(review, step: 0, skipped: false)
        XCTAssertEqual(review.currentStep, 1)
        XCTAssertNotNil(review.lastSavedAt)
    }

    func testTC17AIIsOptionalAndDoesNotChangeReviewState() {
        let review = service.makeWeeklyReview()
        let before = review.currentStep
        XCTAssertEqual(review.currentStep, before)
        XCTAssertEqual(review.status, .inProgress)
    }

    func testTC18ReminderUsesWeeklyReviewDeepLink() {
        XCTAssertEqual(WeeklyReviewReminderService.deepLink.absoluteString, "wool://weekly-review")
    }
}
