import SwiftData

/// Persists a capture at the end of an entry workflow. Items may be raw Inbox
/// captures while a confirmation screen is open.
///
/// The UI and App Intents deliberately share this final write so a capture has
/// the same SwiftData and CloudKit behavior regardless of its entry point.
@MainActor
enum CapturePersistenceService {
    static func save(_ item: TaskItem, in context: ModelContext) throws {
        context.insert(item)
        try context.save()
    }
}
