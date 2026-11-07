import Foundation
import SwiftData

@Model
final class WeeklyReview {
    var id: UUID = UUID()
    var weekStart: Date = Date()
    var weekEnd: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    var statusRawValue: String = WeeklyReviewStatus.notStarted.rawValue
    var currentStep: Int = 0
    var completedStepCount: Int = 0
    var skippedStepCount: Int = 0
    var isPartial: Bool = false
    var streakAtCompletion: Int = 0
    var lastSavedAt: Date = Date()
    var staleTaskIDs: [String] = []
    var staleItemsPreparedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \WeeklyReviewItem.review)
    var checklistItems: [WeeklyReviewItem]? = []

    var status: WeeklyReviewStatus {
        get { WeeklyReviewStatus(rawValue: statusRawValue) ?? .notStarted }
        set {
            statusRawValue = newValue.rawValue
            if newValue == .inProgress { startedAt = startedAt ?? Date() }
            if newValue == .completed || newValue == .partial { completedAt = completedAt ?? Date() }
            lastSavedAt = Date()
        }
    }

    init(weekStart: Date, weekEnd: Date) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
    }
}

@Model
final class WeeklyReviewItem {
    var id: UUID = UUID()
    var title: String = ""
    var instructions: String = ""
    var kindRawValue: String = WeeklyReviewStepKind.collect.rawValue
    var sortOrder: Int = 0
    var isComplete: Bool = false
    var completedAt: Date?
    var isSkipped: Bool = false
    var staleDecisionRawValue: String?

    var review: WeeklyReview?

    var kind: WeeklyReviewStepKind {
        get { WeeklyReviewStepKind(rawValue: kindRawValue) ?? .collect }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        title: String,
        instructions: String = "",
        kind: WeeklyReviewStepKind,
        sortOrder: Int
    ) {
        self.title = title
        self.instructions = instructions
        self.kindRawValue = kind.rawValue
        self.sortOrder = sortOrder
    }

    func markComplete(at date: Date = Date()) {
        isComplete = true
        isSkipped = false
        completedAt = date
    }

    func markSkipped(at date: Date = Date()) {
        isComplete = false
        isSkipped = true
        completedAt = date
    }

    var staleDecision: WeeklyReviewStaleDecision? {
        get { staleDecisionRawValue.flatMap(WeeklyReviewStaleDecision.init(rawValue:)) }
        set { staleDecisionRawValue = newValue?.rawValue }
    }
}
