import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The single capture pipeline shared by the app UI and App Intents.
@MainActor
final class CaptureService {
    static let shared = CaptureService()
    static let foundationModelInputLimit = 4_000

    private let allowsFoundationModel: Bool

    init(allowsFoundationModel: Bool = true) {
        self.allowsFoundationModel = allowsFoundationModel
    }

    /// Categorizes a capture and returns an unsaved SwiftData item.
    func processCapture(text: String) async -> TaskItem {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return TaskItem(title: "", status: .inbox) }

        #if canImport(FoundationModels)
        if allowsFoundationModel, !isTesting, !forcesHeuristicClassification,
           #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.isAvailable,
           let result = await foundationModelResultWithTimeout(for: cleanedText) {
            return makeItem(from: cleanedText, status: result.status, area: result.area, dueDate: result.dueDate)
        }
        #endif

        let fallback = heuristicResult(for: cleanedText)
        return makeItem(from: cleanedText, status: fallback.status, area: fallback.area, dueDate: fallback.dueDate)
    }

    /// Creates an Inbox capture without waiting for Foundation Models. Inbox
    /// is intentionally unprocessed, so this path must stay fast; full AI
    /// classification is performed later by the triage workflow.
    func processInboxCapture(text: String) -> TaskItem {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return TaskItem(title: "", status: .inbox) }

        let fallback = heuristicResult(for: cleanedText)
        let item = makeItem(from: cleanedText, status: fallback.status, area: fallback.area, dueDate: fallback.dueDate)
        item.status = .inbox
        return item
    }

    private struct Classification {
        let status: Status
        let area: String?
        let dueDate: Date?
    }

    private var isTesting: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("-ui-testing") ||
            processInfo.environment["WOOL_UI_TESTING"] == "1" ||
            processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// The two-device CloudKit test uses a deterministic payload. This is
    /// intentionally opt-in and never enabled by normal app or UI-test runs.
    private var forcesHeuristicClassification: Bool {
        ProcessInfo.processInfo.environment["WOOL_CAPTURE_FORCE_HEURISTICS"] == "1"
    }

    private func makeItem(from text: String, status: Status, area: String?, dueDate: Date?) -> TaskItem {
        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        let title = String(lines.first ?? Substring(text))
        let notes = lines.count > 1 ? String(lines[1]) : ""
        return TaskItem(title: title, notes: notes, status: status, dueDate: dueDate, contextTags: area.map { ["area:\($0)"] } ?? [])
    }

    private func heuristicResult(for text: String) -> Classification {
        let normalized = text.lowercased()
        let status: Status
        if normalized.contains("waiting") || normalized.contains("reply") || normalized.contains("hear back") || normalized.contains("follow up") {
            status = .waitingFor
        } else if normalized.contains("someday") || normalized.contains("maybe") || normalized.contains("one day") {
            status = .somedayMaybe
        } else if normalized.range(of: "\\b(call|email|buy|send|schedule|book|review|finish|pay)\\b", options: .regularExpression) != nil {
            status = .nextAction
        } else {
            status = .inbox
        }

        let area: String?
        if normalized.contains("work") || normalized.contains("office") || normalized.contains("client") { area = "Work" } else if normalized.contains("doctor") || normalized.contains("dentist") || normalized.contains("health") || normalized.contains("gym") { area = "Health" } else if normalized.contains("family") || normalized.contains("home") || normalized.contains("personal") { area = "Personal" } else { area = nil }
        return Classification(status: status, area: area, dueDate: parseDate(in: normalized))
    }

    private func parseDate(in text: String) -> Date? {
        if text.contains("tomorrow") { return Calendar.current.date(byAdding: .day, value: 1, to: .now) }
        if text.contains("today") { return .now }
        let weekdays = Calendar.current.weekdaySymbols
        if let weekdayIndex = weekdays.firstIndex(where: { text.range(of: $0.lowercased()) != nil }) {
            let targetWeekday = weekdayIndex + 1
            let currentWeekday = Calendar.current.component(.weekday, from: .now)
            var daysAhead = (targetWeekday - currentWeekday + 7) % 7
            if daysAhead == 0 { daysAhead = 7 }
            if text.contains("next next") { daysAhead += 7 }
            return Calendar.current.date(byAdding: .day, value: daysAhead, to: .now)
        }
        return nil
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty, value.lowercased() != "none" else { return nil }
        if let relative = parseDate(in: value.lowercased()) { return relative }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func foundationModelResultWithTimeout(for text: String) async -> Classification? {
        await withTaskGroup(of: Classification?.self) { group in
            group.addTask { await self.foundationModelResult(for: text) }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }

            let result = await group.next()
            group.cancelAll()
            return result
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func foundationModelResult(for text: String) async -> Classification? {
        let session = LanguageModelSession(instructions: """
            Classify task organization captures. Return exactly three lines:
            status=<inbox|nextAction|waitingFor|somedayMaybe>
            area=<short area name or none>
            due=<YYYY-MM-DD, today, tomorrow, or none>
            Never invent a date or area. Use nextAction only for a concrete physical action.
            """)
        // Keep the persisted capture complete, but bound the prompt sent to
        // on-device inference so paragraph-sized captures remain triageable.
        let promptText = Self.foundationModelPrompt(for: text)
        guard let response = try? await session.respond(to: promptText) else { return nil }
        let fields = response.content.split(separator: "\n").reduce(into: [String: String]()) { result, line in
            let pieces = line.split(separator: "=", maxSplits: 1).map(String.init)
            if pieces.count == 2 { result[pieces[0].lowercased()] = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let status = Status(rawValue: fields["status"] ?? "") ?? .inbox
        let area = fields["area"].flatMap { $0.lowercased() == "none" ? nil : $0 }
        return Classification(status: status, area: area, dueDate: parseDate(fields["due"]))
    }

    static func foundationModelPrompt(for text: String) -> String {
        String(text.prefix(foundationModelInputLimit))
    }
    #endif
}
