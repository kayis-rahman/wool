import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var title: String = ""
    var desiredOutcome: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    var statusRawValue: String = ProjectStatus.active.rawValue
    var isArchived: Bool = false
    var statusBeforeArchiveRawValue: String?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = []

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRawValue) ?? .active }
        set {
            statusRawValue = newValue.rawValue
            completedAt = newValue == .completed ? (completedAt ?? Date()) : nil
            updatedAt = Date()
        }
    }

    func archive(at date: Date = .now) {
        guard !isArchived else { return }
        statusBeforeArchiveRawValue = statusRawValue
        isArchived = true
        updatedAt = date
    }

    func restore(at date: Date = .now) {
        guard isArchived else { return }
        let restoredStatus = ProjectStatus(rawValue: statusBeforeArchiveRawValue ?? ProjectStatus.active.rawValue) ?? .active
        statusRawValue = restoredStatus.rawValue
        statusBeforeArchiveRawValue = nil
        isArchived = false
        if status != .completed { completedAt = nil }
        updatedAt = date
    }

    init(title: String, desiredOutcome: String = "", notes: String = "") {
        self.title = title
        self.desiredOutcome = desiredOutcome
        self.notes = notes
    }
}
