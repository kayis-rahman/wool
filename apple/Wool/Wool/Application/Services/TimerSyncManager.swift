import Foundation
import Observation

/// Local timer coordinator.
///
/// Timer state is persisted by `PomodoroTimer` through `FocusTimerPersistence`.
/// Cross-device timer HTTP/WebSocket synchronization was removed; SwiftData
/// and CloudKit remain the app's shared-data path.
@MainActor
@Observable
final class TimerSyncManager {
    static let shared = TimerSyncManager()

    private(set) var timer: PomodoroTimer?

    private init() {}

    func configure(with timer: PomodoroTimer, accessToken: String? = nil) {
        self.timer = timer
    }

    func getTimer() -> PomodoroTimer? {
        timer
    }

    /// Keeps the existing call-site API while applying the action locally.
    func syncTimerAction(_ action: TimerAction) async {
        guard let timer else { return }

        switch action {
        case .start:
            timer.start()
        case .pause, .stop:
            timer.pause()
        case .reset:
            timer.reset()
        case .advance:
            timer.advance()
        }
    }

    /// Retained for compatibility with older settings call sites. There is no
    /// remote timer state to pull now; local state is already authoritative.
    func syncTimerState() async {}

    /// Legacy push entry point. Remote timer pushes are no longer consumed.
    func applyEventState(from _: [AnyHashable: Any]) {}

    /// Apply timer state received from the paired Apple Watch locally.
    func applyIncomingState(_ state: [String: Any]) {
        guard let timer else { return }

        let phase = Phase(rawValue: state["phase"] as? String ?? "work") ?? .work
        let remainingSeconds = state["remainingSeconds"] as? Int ?? timer.currentDuration
        let isRunning = state["isRunning"] as? Bool ?? false
        let workDuration = state["workDuration"] as? Int ?? timer.workDuration
        let breakDuration = state["breakDuration"] as? Int ?? timer.breakDuration
        let longBreakDuration = state["longBreakDuration"] as? Int ?? timer.longBreakDuration
        let autoStartNextSession = state["autoStartNextSession"] as? Bool ?? timer.autoStartNextSession
        let shortBreaksCompleted = state["shortBreaksCompleted"] as? Int ?? timer.shortBreaksCompleted
        let startTimestamp = state["startTimestamp"] as? Double
        let pauseTimestamp = state["pauseTimestamp"] as? Double
        let modified = state["lastModifiedTimestamp"] as? Double ?? Date().timeIntervalSince1970

        guard modified > timer.lastModifiedTimestamp else { return }

        timer.applySyncedState(
            phase: phase,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            workDuration: workDuration,
            breakDuration: breakDuration,
            longBreakDuration: longBreakDuration,
            autoStartNextSession: autoStartNextSession,
            shortBreaksCompleted: shortBreaksCompleted,
            startTimestamp: startTimestamp,
            pauseTimestamp: pauseTimestamp,
            lastModifiedTimestamp: modified
        )
        timer.persistState()
    }
}
