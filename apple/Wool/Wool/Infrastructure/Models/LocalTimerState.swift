import Foundation

/**
 * Local timer state shared across managers
 */
struct LocalTimerState {
    var remainingSeconds: Int
    var phase: String
    var isRunning: Bool
    var lastEventTime: Date?
}