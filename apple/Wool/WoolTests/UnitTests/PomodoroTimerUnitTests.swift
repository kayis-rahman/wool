//  PomodoroTimerUnitTests.swift
//  WoolTests
//
//  Created by Wool Team
//  Unit tests for PomodoroTimer timestamp-based sync

import XCTest
@testable import Wool

@MainActor
final class PomodoroTimerUnitTests: XCTestCase {

    private var timer: PomodoroTimer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        timer = PomodoroTimer()
    }

    override func tearDownWithError() throws {
        timer = nil
        try super.tearDownWithError()
    }

    func testStartSetsTimestamps() async {
        // Given
        let before = Date().timeIntervalSince1970

        // When
        timer.start()

        // Then
        XCTAssertNotNil(timer.startTimestamp)
        XCTAssertNil(timer.pauseTimestamp)
        XCTAssertGreaterThan(timer.startTimestamp!, before)
        XCTAssertGreaterThan(timer.lastModifiedTimestamp, before)
    }

    func testPauseSetsTimestamps() async {
        // Given
        timer.start()

        // When
        let beforePause = Date().timeIntervalSince1970
        timer.pause()

        // Then
        XCTAssertNotNil(timer.pauseTimestamp)
        XCTAssertGreaterThan(timer.pauseTimestamp!, beforePause)
        XCTAssertGreaterThan(timer.lastModifiedTimestamp, beforePause)
    }

    func testPauseIgnoreWithin2Seconds() async {
        // Given
        timer.start()

        // When
        let beforePause = Date()
        // Wait less than 2 seconds
        try? await Task.sleep(nanoseconds: 500_000_000)
        timer.pause()

        // Then
        // Pause should be ignored, timer still running
        XCTAssertTrue(timer.isRunning)
        XCTAssertNil(timer.pauseTimestamp)
    }

    func testPauseExecuteAfter2Seconds() async {
        // Given
        timer.start()

        // When
        // Wait more than 2 seconds
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        timer.pause()

        // Then
        XCTAssertFalse(timer.isRunning)
        XCTAssertNotNil(timer.pauseTimestamp)
    }

    func testRemainingSecondsDouble() async {
        // Given
        timer.start()

        // When
        timer.remainingSeconds = 1234

        // Then
        XCTAssertEqual(timer.remainingSeconds, 1234)
    }

    func testProgressCalculation() async {
        // Given
        timer.remainingSeconds = 750 // Half of 1500

        // When
        let progress = timer.progress

        // Then
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }
}