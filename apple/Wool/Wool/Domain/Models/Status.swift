import Foundation

enum Status: String, Codable, CaseIterable, Sendable {
    case inbox
    case nextAction
    case waitingFor
    case somedayMaybe
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .nextAction: "Next Action"
        case .waitingFor: "Waiting For"
        case .somedayMaybe: "Someday / Maybe"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case active
    case completed
    case cancelled
}

enum WeeklyReviewStatus: String, Codable, CaseIterable, Sendable {
    case notStarted
    case inProgress
    case completed
    case partial
}

enum WeeklyReviewStepKind: String, Codable, CaseIterable, Sendable {
    case collect
    case process
    case stale
    case organize
    case review
    case plan
}

enum WeeklyReviewStaleDecision: String, Codable, CaseIterable, Sendable {
    case promote
    case keep
    case delete
}
