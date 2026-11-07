import Foundation

enum FocusSessionStatus: String, Codable, Sendable {
    case running
    case paused
    case completed
    case abandoned
}

struct FocusSessionLifecycleRecord: Codable, Equatable, Sendable {
    let id: UUID
    let phase: Phase
    let status: FocusSessionStatus
    let startedAt: Date
    let lastUpdatedAt: Date
    let accumulatedElapsedSeconds: Int
    let taskId: UUID?
    let taskTitleSnapshot: String?
}

/// Durable local history for the active Focus session lifecycle.
///
/// `FocusTimerPersistence` remains the fast active-state snapshot. This store
/// records the last lifecycle transition separately, so a completed or
/// abandoned session cannot be mistaken for a still-running snapshot after a
/// relaunch or duplicate completion callback.
enum FocusSessionLifecycleStore {
    static let storageKey = "FocusSession.lifecycle.v1"

    static func save(_ record: FocusSessionLifecycleRecord, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func load(defaults: UserDefaults = .standard) -> FocusSessionLifecycleRecord? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FocusSessionLifecycleRecord.self, from: data)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
