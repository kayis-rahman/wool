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
}
