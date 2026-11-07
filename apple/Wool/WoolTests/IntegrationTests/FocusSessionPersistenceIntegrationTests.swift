import SwiftData
import XCTest
@testable import Wool

@MainActor
final class FocusSessionPersistenceIntegrationTests: XCTestCase {
    private let recordsKey = "SessionLogger.records.v1"

    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.standard.removeObject(forKey: recordsKey)
        FocusTimerPersistence.clear()
        FocusSessionLifecycleStore.clear()
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: recordsKey)
        FocusTimerPersistence.clear()
        FocusSessionLifecycleStore.clear()
        try super.tearDownWithError()
    }

    func testGenericFocusSessionPersistsAcrossLoggerReload() {
        let sessionID = UUID()
        let logger = SessionLogger()
        logger.add(record: SessionRecord(
            id: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 1_500,
            kind: .work
        ))

        let reloadedLogger = SessionLogger()

        XCTAssertEqual(reloadedLogger.records.map(\.id), [sessionID])
        XCTAssertNil(reloadedLogger.records.first?.taskId)
        XCTAssertEqual(reloadedLogger.records.first?.durationSeconds, 1_500)
    }

    func testTaskLinkedFocusSessionPersistsTaskIdentityAndSnapshot() {
        let taskID = UUID()
        let sessionID = UUID()
        let logger = SessionLogger()
        logger.add(record: SessionRecord(
            id: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 1_500,
            kind: .work,
            taskId: taskID,
            taskTitleSnapshot: "Review roadmap"
        ))

        let reloadedLogger = SessionLogger()
        let persisted = reloadedLogger.records.first

        XCTAssertEqual(persisted?.id, sessionID)
        XCTAssertEqual(persisted?.taskId, taskID)
        XCTAssertEqual(persisted?.taskTitleSnapshot, "Review roadmap")
    }

    func testOfflineTestingContainerPersistsTaskFixtureLocally() throws {
        let marker = UUID().uuidString
        let context = ModelContext(WoolModelContainer.shared)
        let task = TaskItem(title: "Focus fixture \(marker)", status: .nextAction)

        context.insert(task)
        try context.save()

        let taskID = task.id
        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID }))

        XCTAssertNil(WoolModelContainer.configuration(isTesting: true).cloudKitContainerIdentifier)
        XCTAssertEqual(saved.first?.title, "Focus fixture \(marker)")
        XCTAssertEqual(saved.first?.status, .nextAction)
    }

    func testActiveTimerSnapshotSurvivesRecreatedTimer() {
        let timer = PomodoroTimer(workDuration: 60, breakDuration: 5)
        let taskID = UUID()
        XCTAssertTrue(timer.selectTask(id: taskID, title: "Persist focus state"))
        timer.start()
        let sessionID = timer.activeSessionId
        timer.persistState()

        let recreated = PomodoroTimer(workDuration: 60, breakDuration: 5)
        recreated.restorePersistedState()

        XCTAssertEqual(recreated.activeSessionId, sessionID)
        XCTAssertEqual(recreated.currentTaskId, taskID)
        XCTAssertEqual(recreated.currentTaskTitleSnapshot, "Persist focus state")
        XCTAssertTrue(recreated.isRunning)
        timer.pause()
        recreated.pause()
    }
}
