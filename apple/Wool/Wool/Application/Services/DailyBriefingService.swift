#if canImport(UserNotifications)
import UserNotifications
#endif
import Foundation

#if canImport(EventKit)
import EventKit
#endif

struct DailyBriefingEvent: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?

    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
    }
}

struct DailyBriefingItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let dueDate: Date?
}

struct DailyBriefingSections: Sendable, Equatable {
    let day: Date
    let dueToday: [DailyBriefingItem]
    let overdue: [DailyBriefingItem]
    let waiting: [DailyBriefingItem]
    let upNext: [DailyBriefingItem]
    let calendarEvents: [DailyBriefingEvent]
    let isFirstRun: Bool

    var hasWork: Bool { !dueToday.isEmpty || !overdue.isEmpty || !waiting.isEmpty || !upNext.isEmpty || !calendarEvents.isEmpty }
    var allDayCalendarEvents: [DailyBriefingEvent] { calendarEvents.filter(\.isAllDay) }
    var timedCalendarEvents: [DailyBriefingEvent] { calendarEvents.filter { !$0.isAllDay } }
}

struct DailyBriefingResult: Sendable, Equatable {
    let sections: DailyBriefingSections
    let narrative: String?

    var summaryText: String? {
        guard !sections.isFirstRun, sections.dueToday.isEmpty else { return nil }
        return sections.waiting.isEmpty
            ? "All clear — nothing is due today."
            : "Nothing due today, \(sections.waiting.count) item\(sections.waiting.count == 1 ? "" : "s") in Waiting For."
    }

    var plainText: String {
        if sections.isFirstRun { return "Welcome to Wool. Capture your first thought to start your day." }

        var lines: [String] = []
        if sections.dueToday.isEmpty {
            lines.append(sections.waiting.isEmpty
                ? "All clear — nothing is due today."
                : "Nothing due today, \(sections.waiting.count) item\(sections.waiting.count == 1 ? "" : "s") in Waiting For.")
        } else {
            lines.append("Due today")
            lines.append(contentsOf: sections.dueToday.map { "• \($0.title)" })
        }
        if !sections.overdue.isEmpty {
            lines.append("Overdue")
            lines.append(contentsOf: sections.overdue.map { "• \($0.title)" })
        }
        if !sections.waiting.isEmpty {
            lines.append("Check on this")
            lines.append(contentsOf: sections.waiting.map { "• \($0.title)" })
        }
        if !sections.upNext.isEmpty {
            lines.append("Up next")
            lines.append(contentsOf: sections.upNext.map { "• \($0.title)" })
        }
        if !sections.calendarEvents.isEmpty {
            let count = sections.calendarEvents.count
            lines.append("Calendar: \(count) event\(count == 1 ? "" : "s")")
        }
        return lines.joined(separator: "\n")
    }
}

enum DailyBriefingCalendarAuthorization: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    var isAuthorized: Bool { self == .authorized }
}

@MainActor
protocol DailyBriefingCalendarProvider {
    var authorization: DailyBriefingCalendarAuthorization { get }
    func requestAccessIfNeeded() async -> Bool
    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent]
}

extension DailyBriefingCalendarProvider {
    var authorization: DailyBriefingCalendarAuthorization { .unavailable }
    func requestAccessIfNeeded() async -> Bool { false }
}

@MainActor
struct EmptyDailyBriefingCalendarProvider: DailyBriefingCalendarProvider {
    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] { [] }
}

@MainActor
private struct DailyBriefingUITestCalendarProvider: DailyBriefingCalendarProvider {
    var authorization: DailyBriefingCalendarAuthorization { .authorized }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        let start = calendar.startOfDay(for: day)
        return [
            DailyBriefingEvent(id: "ui-calendar-all-day", title: "UI Test Team Offsite", startDate: start, endDate: calendar.date(byAdding: .day, value: 1, to: start) ?? start, isAllDay: true),
            DailyBriefingEvent(id: "ui-calendar-timed", title: "UI Test Planning", startDate: start.addingTimeInterval(3600 * 10), endDate: start.addingTimeInterval(3600 * 11), isAllDay: false, location: "Studio")
        ]
    }
}

#if canImport(EventKit)
@MainActor
final class EventKitDailyBriefingCalendarProvider: DailyBriefingCalendarProvider {
    private let store = EKEventStore()

    var authorization: DailyBriefingCalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .writeOnly: return .unavailable
        @unknown default: return .unavailable
        }
    }

    func requestAccessIfNeeded() async -> Bool {
        guard authorization == .notDetermined else { return authorization.isAuthorized }
        if #available(iOS 17.0, macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                store.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func events(for day: Date, calendar: Calendar) async throws -> [DailyBriefingEvent] {
        guard authorization.isAuthorized else { return [] }

        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .compactMap { event in
                guard let id = event.eventIdentifier else { return nil }
                return DailyBriefingEvent(
                    id: id,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { $0.startDate < $1.startDate }
    }
}
#endif

enum DailyBriefingComposer {
    static func sections(
        from tasks: [TaskItem],
        now: Date = .now,
        calendar: Calendar = .current,
        calendarEvents: [DailyBriefingEvent] = [],
        isFirstRun: Bool = false
    ) -> DailyBriefingSections {
        let open = tasks.filter { $0.status != .completed && $0.status != .cancelled }
        let nextActions = open.filter { $0.status == .nextAction }
        let dueToday = nextActions.filter { date in
            guard let dueDate = date.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: now)
        }
        let startOfToday = calendar.startOfDay(for: now)
        let overdue = open.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday
        }
        // Waiting For is always useful context in a morning briefing. A past
        // follow-up date makes it actionable, but a future follow-up still
        // belongs in the count and distinct section.
        let waiting = open.filter { $0.status == .waitingFor }
        let upNext = nextActions
            .filter { $0.dueDate == nil }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
            .prefix(5)

        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        var seenCalendarIDs = Set<String>()
        let validCalendarEvents = calendarEvents
            .filter { !$0.id.isEmpty && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.startDate <= $0.endDate }
            .filter { $0.endDate > dayStart && $0.startDate < dayEnd }
            .filter { seenCalendarIDs.insert($0.id).inserted }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay && !$1.isAllDay }
                return $0.id < $1.id
            }

        func item(_ task: TaskItem) -> DailyBriefingItem {
            DailyBriefingItem(id: task.id, title: task.title, dueDate: task.dueDate)
        }
        return DailyBriefingSections(
            day: calendar.startOfDay(for: now),
            dueToday: dueToday.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.map(item),
            overdue: overdue.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.map(item),
            waiting: waiting.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.map(item),
            upNext: upNext.map(item),
            calendarEvents: validCalendarEvents,
            isFirstRun: isFirstRun
        )
    }
}

@MainActor
final class DailyBriefingService {
    static let shared = DailyBriefingService()

    private let calendarProvider: any DailyBriefingCalendarProvider
    private let narrativeProvider: DailyBriefingNarrativeProvider

    init(
        calendarProvider: (any DailyBriefingCalendarProvider)? = nil,
        narrativeProvider: @escaping DailyBriefingNarrativeProvider = { sections in
            await OnDeviceIntelligenceService.shared.briefingNarrative(for: sections)
        }
    ) {
        self.calendarProvider = calendarProvider ?? Self.defaultCalendarProvider
        self.narrativeProvider = narrativeProvider
    }

    static var defaultCalendarProvider: any DailyBriefingCalendarProvider {
        #if canImport(EventKit)
        if ProcessInfo.processInfo.environment["WOOL_UI_TEST_SEED_DAILY_BRIEFING_CALENDAR"] == "1" {
            return DailyBriefingUITestCalendarProvider()
        }
        if ProcessInfo.processInfo.environment["WOOL_UI_TESTING"] == "1" {
            return EmptyDailyBriefingCalendarProvider()
        }
        return EventKitDailyBriefingCalendarProvider()
        #else
        return EmptyDailyBriefingCalendarProvider()
        #endif
    }

    var calendarAccessCacheKey: String {
        calendarProvider.authorization.rawValue
    }

    func makeBriefing(tasks: [TaskItem], now: Date = .now, isFirstRun: Bool = false) async -> DailyBriefingResult {
        let calendar = Calendar.current
        if calendarProvider.authorization == .notDetermined {
            _ = await calendarProvider.requestAccessIfNeeded()
        }
        let events = (try? await calendarProvider.events(for: now, calendar: calendar)) ?? []
        let sections = DailyBriefingComposer.sections(
            from: tasks,
            now: now,
            calendar: calendar,
            calendarEvents: events,
            isFirstRun: isFirstRun
        )
        let generatedNarrative = await narrativeProvider(sections)
        let trimmedNarrative = generatedNarrative?.trimmingCharacters(in: .whitespacesAndNewlines)
        let narrative = trimmedNarrative?.isEmpty == false ? trimmedNarrative : nil
        return DailyBriefingResult(sections: sections, narrative: narrative)
    }
}

typealias DailyBriefingNarrativeProvider = @MainActor (DailyBriefingSections) async -> String?

@MainActor
final class DailyBriefingReminderService {
    static let shared = DailyBriefingReminderService()
    static let notificationIdentifier = "wool.daily-briefing.reminder"
    static let deepLink = URL(string: "wool://daily-briefing")!

    func schedule(
        hour: Int = 8,
        minute: Int = 0,
        center: any LocalNotificationCenter = UNUserNotificationCenter.current()
    ) {
        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Daily Briefing"
        content.body = "Review due work and plan your day."
        content.sound = .default
        content.userInfo = ["type": "daily_briefing", "deepLink": Self.deepLink.absoluteString]

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.add(request)
    }

    func cancel(center: any LocalNotificationCenter = UNUserNotificationCenter.current()) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
