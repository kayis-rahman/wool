import XCTest
@testable import Wool

@MainActor
final class SessionLoggerTests: XCTestCase {

    private var logger: SessionLogger!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Clear persisted data between tests
        UserDefaults.standard.removeObject(forKey: "SessionLogger.records.v1")
        logger = SessionLogger()
    }

    override func tearDownWithError() throws {
        logger = nil
        try super.tearDownWithError()
    }

    // MARK: - Add & Clear

    func testAddRecord() async {
        let record = SessionRecord(
            startedAt: Date(),
            duration: 1500,
            kind: .work
        )
        logger.add(record: record)

        XCTAssertEqual(logger.records.count, 1)
        XCTAssertEqual(logger.records.first?.kind, "WORK")
    }

    func testClearRecords() async {
        logger.add(record: SessionRecord(startedAt: Date(), duration: 1500, kind: .work))
        logger.add(record: SessionRecord(startedAt: Date(), duration: 300, kind: .shortBreak))

        logger.clear()

        XCTAssertEqual(logger.records.count, 0)
    }

    func testPersistenceAcrossInstances() async {
        let record = SessionRecord(startedAt: Date(), duration: 900, kind: .longBreak)
        logger.add(record: record)

        logger = SessionLogger()

        XCTAssertEqual(logger.records.count, 1)
        XCTAssertEqual(logger.records.first?.kind, "LONG_BREAK")
    }

    // MARK: - DTO Conversion

    func testAddConvertsToDTO() async {
        let record = SessionRecord(startedAt: Date(), duration: 1500, kind: .work)

        logger.add(record: record)

        let dto = logger.records.first
        XCTAssertNotNil(dto)
        XCTAssertEqual(dto?.kind, "WORK")
        XCTAssertEqual(dto?.durationSeconds, 1500)
    }

    func testDTOPreservesTimestamp() async {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = SessionRecord(startedAt: startedAt, duration: 600, kind: .shortBreak)

        logger.add(record: record)

        XCTAssertEqual(logger.records.first?.startedAt, startedAt)
        XCTAssertEqual(logger.records.first?.durationSeconds, 600)
    }

    func testGenericFocusSessionPreservesNilTaskAssociation() {
        logger.add(record: SessionRecord(
            startedAt: Date(),
            duration: 1500,
            kind: .work
        ))

        XCTAssertNil(logger.records.first?.taskId)
    }

    func testTaskAssociationAndTitleSnapshotSurviveDTOConversion() {
        let taskID = UUID()
        logger.add(record: SessionRecord(
            startedAt: Date(),
            duration: 1500,
            kind: .work,
            taskId: taskID,
            taskTitleSnapshot: "Write implementation plan"
        ))

        XCTAssertEqual(logger.records.first?.taskId, taskID)
        XCTAssertEqual(logger.records.first?.taskTitleSnapshot, "Write implementation plan")
    }

    func testAddingSameSessionIDTwiceIsIdempotent() {
        let sessionID = UUID()
        let record = SessionRecord(
            id: sessionID,
            startedAt: Date(),
            duration: 1500,
            kind: .work
        )

        logger.add(record: record)
        logger.add(record: record)

        XCTAssertEqual(logger.records.count, 1)
        XCTAssertEqual(logger.records.first?.id, sessionID)
    }

    // MARK: - Field Preservation

    func testDTOPreservesDuration() async {
        logger.add(record: SessionRecord(startedAt: Date(), duration: 2700, kind: .longBreak))

        XCTAssertEqual(logger.records.first?.durationSeconds, 2700)
    }

    func testMultipleRecordsOrdered() async {
        let r1 = SessionRecord(startedAt: Date(timeIntervalSince1970: 1000), duration: 100, kind: .work)
        let r2 = SessionRecord(startedAt: Date(timeIntervalSince1970: 2000), duration: 200, kind: .shortBreak)

        logger.add(record: r1)
        logger.add(record: r2)

        XCTAssertEqual(logger.records.count, 2)
        XCTAssertEqual(logger.records[0].durationSeconds, 100)
        XCTAssertEqual(logger.records[1].durationSeconds, 200)
    }
}
