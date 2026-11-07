#if os(iOS)
import ActivityKit
import Foundation

@MainActor
final class FocusLiveActivityManager {
    static let shared = FocusLiveActivityManager()

    private var activity: Activity<FocusLiveActivityAttributes>?

    private init() {}

    func sync(with timer: PomodoroTimer) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            let state = makeState(from: timer)

            if let activity {
                await activity.update(ActivityContent(state: state, staleDate: staleDate(for: timer)))
            } else if timer.isRunning || timer.remainingSeconds < timer.currentDuration {
                await start(with: timer, state: state)
            }
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func start(with timer: PomodoroTimer, state: FocusLiveActivityAttributes.ContentState) async {
        guard activity == nil else { return }

        do {
            activity = try Activity.request(
                attributes: FocusLiveActivityAttributes(sessionID: timer.activeSessionId?.uuidString ?? UUID().uuidString),
                content: ActivityContent(state: state, staleDate: staleDate(for: timer)),
                pushType: nil
            )
        } catch {
            // Live Activities are an enhancement; timer operation continues normally.
        }
    }

    private func makeState(from timer: PomodoroTimer) -> FocusLiveActivityAttributes.ContentState {
        FocusLiveActivityAttributes.ContentState(
            phase: timer.phase.displayName,
            endDate: timer.isRunning ? timer.endAt : nil,
            remainingSeconds: max(0, timer.remainingSeconds),
            isPaused: !timer.isRunning,
            cycleNumber: min(timer.shortBreaksCompleted + 1, timer.cycleSize),
            cycleSize: timer.cycleSize,
            taskTitle: timer.currentTaskTitleSnapshot
        )
    }

    private func staleDate(for timer: PomodoroTimer) -> Date? {
        timer.endAt?.addingTimeInterval(60)
    }
}
#endif
