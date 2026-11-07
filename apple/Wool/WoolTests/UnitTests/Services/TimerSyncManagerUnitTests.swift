//
//  TimerSyncManagerUnitTests.swift
//  WoolTests
//
//  Unit tests for TimerSyncManager
//

import XCTest
@testable import Wool

@MainActor
final class TimerSyncManagerUnitTests: XCTestCase {
    private var mockTimer: PomodoroTimer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockTimer = PomodoroTimer()
        let syncManager = TimerSyncManager.shared
        syncManager.configure(with: mockTimer)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    // MARK: - Timer Configuration Tests

    func testTimerConfiguration() async {
        // When: Timer is configured
        TimerSyncManager.shared.configure(with: mockTimer)

        // Then: Should store the timer reference
        let timer = TimerSyncManager.shared.getTimer()
        XCTAssertNotNil(timer)
    }

    func testGetTimerReturnsConfiguredTimer() async {
        // When: Timer is configured
        TimerSyncManager.shared.configure(with: mockTimer)

        // Then: getTimer should return the mock timer
        let timer = TimerSyncManager.shared.getTimer()
        XCTAssertNotNil(timer)
        XCTAssertTrue(timer === mockTimer)
    }

    // MARK: - Sync Action Smoke Tests

    func testSyncActionStartDoesNotCrash() async {
        // Given
        mockTimer.phase = .work
        mockTimer.isRunning = false

        // When: sync start action (may fail auth, which is expected)
        await TimerSyncManager.shared.syncTimerAction(.start)

        // Then: local timer should be updated
        XCTAssertTrue(mockTimer.isRunning)
    }

    func testSyncActionPauseDoesNotCrash() async {
        // Given
        mockTimer.phase = .work
        mockTimer.isRunning = true

        // When: sync pause action
        await TimerSyncManager.shared.syncTimerAction(.pause)

        // Then: local timer should be paused
        XCTAssertFalse(mockTimer.isRunning)
    }

    func testSyncActionResetDoesNotCrash() async {
        // Given
        mockTimer.phase = .work
        mockTimer.remainingSeconds = 1500
        mockTimer.isRunning = true

        // When: sync reset action
        await TimerSyncManager.shared.syncTimerAction(.reset)

        // Then: local timer should be reset
        XCTAssertEqual(mockTimer.phase, .work)
        XCTAssertEqual(mockTimer.shortBreaksCompleted, 0)
    }
}
