import Foundation
import SwiftData

enum AreaNameValidationError: LocalizedError, Equatable {
    case empty
    case duplicate

    var errorDescription: String? {
        switch self {
        case .empty: "Enter an Area name."
        case .duplicate: "An Area with this name already exists."
        }
    }
}

enum AreaNaming {
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func validate(_ name: String, against areas: [Area]) -> AreaNameValidationError? {
        let cleanName = normalized(name)
        guard !cleanName.isEmpty else { return .empty }
        return areas.contains { normalized($0.name) == cleanName } ? .duplicate : nil
    }
}

@Model
final class Area {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.areas)
    var tasks: [TaskItem]? = []

    init(name: String, notes: String = "") {
        self.name = name
        self.notes = notes
    }
}
