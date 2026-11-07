import Foundation

struct QueuedTimerAction: Codable, Sendable {
    let action: String
    let timestamp: Double
    let phase: String
    let remainingSeconds: Int
    let isRunning: Bool
    let workDuration: Int
    let breakDuration: Int
    let longBreakDuration: Int
    let autoStartNextSession: Bool
    let shortBreaksCompleted: Int

    init(
        action: String,
        timestamp: Double,
        phase: String,
        remainingSeconds: Int,
        isRunning: Bool,
        workDuration: Int,
        breakDuration: Int,
        longBreakDuration: Int,
        autoStartNextSession: Bool,
        shortBreaksCompleted: Int
    ) {
        self.action = action
        self.timestamp = timestamp
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.autoStartNextSession = autoStartNextSession
        self.shortBreaksCompleted = shortBreaksCompleted
    }
}
