import XCTest

//  WoolTests.swift
//  WoolTests
//
//  Created by AI Assistant on 15/09/25.

@testable import Wool

@MainActor
final class WoolTests: XCTestCase {
    func testTimerControlFlow() async throws {
        let timer = PomodoroTimer(workDuration: 3, breakDuration: 2)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remainingSeconds, 3)
        timer.start()
        try await Task.sleep(for: .nanoseconds(1_200_000_000))
        let afterStartRemaining = timer.remainingSeconds
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(afterStartRemaining <= 2 && afterStartRemaining >= 1)
        timer.pause()
        let pausedRemaining = timer.remainingSeconds
        try await Task.sleep(for: .nanoseconds(1_200_000_000))
        let pausedRemainingAfter = timer.remainingSeconds
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(pausedRemainingAfter, pausedRemaining)
        timer.reset()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remainingSeconds, 3)
        XCTAssertFalse(timer.isRunning)
    }

    func testPhaseSwitching() async throws {
        let timer = PomodoroTimer(workDuration: 1, breakDuration: 1)
        timer.start()
        try await Task.sleep(for: .nanoseconds(1_200_000_000))
        XCTAssertEqual(timer.phase, .break)
        try await Task.sleep(for: .nanoseconds(1_200_000_000))
        XCTAssertEqual(timer.phase, .work)
        timer.pause()
    }

    func testProgressCalculation() async throws {
        let timer = PomodoroTimer(workDuration: 4, breakDuration: 2)
        XCTAssertEqual(timer.progress, 0)
        timer.start()
        try await Task.sleep(for: .nanoseconds(1_100_000_000))
        let p1 = timer.progress
        XCTAssertTrue(p1 > 0 && p1 < 1)
        timer.pause()
        timer.remainingSeconds = 0
        let p2 = timer.progress
        XCTAssertEqual(p2, 1)
    }

    func testResetAlwaysWorkPhase() async throws {
        let timer = PomodoroTimer(workDuration: 2, breakDuration: 2)
        timer.start()
        try await Task.sleep(for: .nanoseconds(1_200_000_000))
        XCTAssertEqual(timer.phase, .break)
        timer.reset()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remainingSeconds, 2)
        XCTAssertFalse(timer.isRunning)
    }
}
