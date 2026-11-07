import Foundation

enum FocusTabBehavior {
    static func actionTitle(isRunning: Bool, remainingSeconds: Int, currentDuration: Int) -> String {
        if isRunning { return "Pause focus" }
        return remainingSeconds < currentDuration ? "Resume focus" : "Start focus"
    }

    static func heading(for phase: Phase) -> String {
        switch phase {
        case .work: return "What deserves your attention?"
        case .break, .longBreak: return "Give yourself a breather"
        }
    }

    static func prompt(for phase: Phase, isRunning: Bool, remainingSeconds: Int, currentDuration: Int) -> String {
        if isRunning { return "Stay with this moment." }

        switch phase {
        case .work:
            return remainingSeconds < currentDuration
                ? "Your session is paused."
                : "Choose a task, then begin when you’re ready."
        case .break: return "Step away for a few minutes."
        case .longBreak: return "You’ve earned a longer reset."
        }
    }

    static func formattedFocusTime(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func upNextTasks(from tasks: [TaskItem], excluding currentTaskID: UUID?, limit: Int = 4) -> [TaskItem] {
        tasks.filter { $0.id != currentTaskID }.prefix(max(0, limit)).map { $0 }
    }
}
