import Foundation

enum InboxBehavior {
    static func suggestedProject(in projects: [Project], matching text: String) -> Project? {
        projects.first { !$0.title.isEmpty && text.localizedCaseInsensitiveContains($0.title) }
    }

    static func filteredTasks(_ tasks: [TaskItem], query: String) -> [TaskItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return tasks }
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(normalizedQuery)
                || task.notes.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    static func triageSummary(movedCount: Int) -> String {
        movedCount == 0
            ? "Nothing was moved. Add more context to your captures."
            : "Moved \(movedCount) capture\(movedCount == 1 ? "" : "s") into Lists."
    }

    /// Returns an organized List. Inbox is intentionally excluded because
    /// it has its own capture-processing surface.
    static func organizedTasks(_ tasks: [TaskItem], status: Status) -> [TaskItem] {
        tasks
            .filter { $0.status == status }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (left?, right?):
                    return left == right ? lhs.createdAt > rhs.createdAt : left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.createdAt > rhs.createdAt
                }
            }
    }
}
