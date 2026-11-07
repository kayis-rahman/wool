import Foundation

public struct SessionRecord: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable {
        case work, shortBreak, longBreak

        public var displayName: String {
            switch self {
            case .work: return "Work"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }
    public let id: UUID
    public let startedAt: Date
    public let duration: TimeInterval
    public let kind: Kind
    public let taskId: UUID?
    public let taskTitleSnapshot: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        duration: TimeInterval,
        kind: Kind,
        taskId: UUID? = nil,
        taskTitleSnapshot: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.kind = kind
        self.taskId = taskId
        self.taskTitleSnapshot = taskTitleSnapshot
    }

    public var isProductive: Bool { kind == .work }
}
