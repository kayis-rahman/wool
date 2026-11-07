import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueDate: Date?
    var completedAt: Date?
    var statusRawValue: String = Status.inbox.rawValue
    var contextTags: [String] = []
    var sortOrder: Double = 0

    var project: Project?

    var areas: [Area]? = []

    var status: Status {
        get { Status(rawValue: statusRawValue) ?? .inbox }
        set {
            statusRawValue = newValue.rawValue
            completedAt = newValue == .completed ? (completedAt ?? Date()) : nil
            updatedAt = Date()
        }
    }

    init(
        title: String,
        notes: String = "",
        status: Status = .inbox,
        dueDate: Date? = nil,
        contextTags: [String] = [],
        project: Project? = nil,
        areas: [Area] = []
    ) {
        self.title = title
        self.notes = notes
        self.statusRawValue = status.rawValue
        self.dueDate = dueDate
        self.contextTags = contextTags
        self.project = project
        self.areas = areas
    }
}
