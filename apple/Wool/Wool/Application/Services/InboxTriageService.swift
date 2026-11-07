import Foundation

/// Applies the shared capture classification to existing Inbox items.
@MainActor
enum InboxTriageService {
    static func triage(_ tasks: [TaskItem]) async -> [TaskItem] {
        await triage(tasks, using: CaptureService.shared)
    }

    /// Returns the items moved out of Inbox. Persistence remains the caller's
    /// responsibility, allowing the UI and tests to use the same transition.
    static func triage(
        _ tasks: [TaskItem],
        using captureService: CaptureService
    ) async -> [TaskItem] {
        var movedTasks: [TaskItem] = []

        for task in tasks where task.status == .inbox {
            let recommendation = await captureService.processCapture(text: "\(task.title)\n\(task.notes)")
            guard recommendation.status != .inbox else { continue }

            task.status = recommendation.status
            task.contextTags = recommendation.contextTags
            if let dueDate = recommendation.dueDate {
                task.dueDate = dueDate
            }
            movedTasks.append(task)
        }

        return movedTasks
    }
}
