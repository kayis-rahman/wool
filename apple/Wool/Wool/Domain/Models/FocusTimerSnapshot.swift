import Foundation

struct FocusTimerSnapshot: Codable, Equatable, Sendable {
    let activeSessionId: UUID?
    let phase: Phase
    let remainingSeconds: Int
    let isRunning: Bool
    let shortBreaksCompleted: Int
    let autoStartNextSession: Bool
    let currentTaskId: UUID?
    let taskTitleSnapshot: String?
    let sessionStartedAt: Date?
    let accumulatedElapsedSeconds: Int
    let runStartedAt: Date?
    let lastReconciledAt: Date?
    let endAt: Date?
    let savedAt: Date
}

enum FocusTimerPersistence {
    static let storageKey = "FocusTimer.activeState.v1"

    static func save(_ snapshot: FocusTimerSnapshot, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func load(defaults: UserDefaults = .standard) -> FocusTimerSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FocusTimerSnapshot.self, from: data)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
