import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum IntelligenceCategory: String, CaseIterable, Sendable {
    case inbox
    case nextAction
    case waitingFor
    case somedayMaybe
}

struct TriageRecommendation: Sendable {
    let category: IntelligenceCategory
    let rationale: String
}

@MainActor
final class OnDeviceIntelligenceService {
    static let shared = OnDeviceIntelligenceService()

    private init() {}

    func triage(title: String, notes: String) async -> TriageRecommendation {
        let item = await CaptureService.shared.processCapture(text: "\(title)\n\(notes)")
        let category = IntelligenceCategory(rawValue: item.statusRawValue) ?? .inbox
        return TriageRecommendation(category: category, rationale: "Suggested from the shared capture pipeline.")
    }

    func dailyBriefing(tasks: [TaskItem]) async -> String {
        let openTasks = tasks.filter { $0.status != .completed && $0.status != .cancelled }
        guard !openTasks.isEmpty else { return "You have a clean slate today. Protect the space." }
        let summary = openTasks.prefix(12).map { "- \($0.title) [\($0.status.displayName)]" }.joined(separator: "\n")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: """
                You create calm, concise task organization daily briefings. Mention the most important next actions,
                overdue items, and one encouraging focus. Use plain text and no more than 80 words.
                """)
            if let response = try? await session.respond(to: "Open items:\n\(summary)") {
                return response.content
            }
        }
        #endif

        let actionCount = openTasks.filter { $0.status == .nextAction }.count
        return "You have \(actionCount) next action\(actionCount == 1 ? "" : "s") ready. Start with one small, visible step."
    }

    func briefingNarrative(for sections: DailyBriefingSections) async -> String? {
        guard !sections.isFirstRun, sections.hasWork else { return nil }
        if ProcessInfo.processInfo.environment["WOOL_UI_TEST_DISABLE_AI"] == "1" { return nil }
        let input = """
        Due today: \(sections.dueToday.map(\.title).joined(separator: ", "))
        Overdue: \(sections.overdue.map(\.title).joined(separator: ", "))
        Waiting for follow-up: \(sections.waiting.map(\.title).joined(separator: ", "))
        Calendar: \(sections.calendarEvents.count) events, \(sections.calendarEvents.filter(\.isAllDay).count) all-day
        """

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: """
                Write one calm, concise morning briefing in plain text, under 55 words.
                Mention the focus for today and any meaningful constraint. Do not list every item,
                do not use a heading, and do not invent details.
                """)
            if let response = try? await session.respond(to: input) {
                let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : content
            }
        }
        #endif
        return nil
    }

    func weeklyReviewPrompt(review: WeeklyReview, openTaskCount: Int) async -> String {
        let completed = review.checklistItems?.filter(\.isComplete).count ?? 0
        let total = review.checklistItems?.count ?? 0

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: """
                You guide a task organization weekly review. Ask one short, practical reflection question based on progress.
                Do not judge. Keep it under 35 words.
                """)
            if let response = try? await session.respond(to: "Checklist: \(completed)/\(total) complete. Open tasks: \(openTaskCount).") {
                return response.content
            }
        }
        #endif

        return completed == total && total > 0
            ? "Your review is complete. What will make next week feel lighter?"
            : "What is the next physical action that would make this review easier?"
    }

}
