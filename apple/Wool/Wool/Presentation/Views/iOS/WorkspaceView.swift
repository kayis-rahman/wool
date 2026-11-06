import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

private func weeklyReviewProjectMessage(flaggedCount: Int) -> String {
    guard flaggedCount > 0 else { return "All active projects have a next action defined" }
    let label = flaggedCount == 1 ? "project" : "projects"
    let verb = flaggedCount == 1 ? "needs" : "need"
    return String(flaggedCount) + " " + label + " " + verb + " next action defined"
}

private struct WeeklyReviewProjectStatusView: View {
    let flaggedCount: Int

    var body: some View {
        Text(weeklyReviewProjectMessage(flaggedCount: flaggedCount))
            .font(.caption.weight(.medium))
            .foregroundStyle(flaggedCount == 0 ? Color.secondary : Color.orange)
            .accessibilityIdentifier("review-projects-status")
    }
}

#if os(iOS)
struct WorkspaceView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Today", systemImage: todayTabSymbol) }
                .tag(0)
            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.fill") }
                .tag(1)
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "square.stack.3d.up.fill") }
                .tag(2)
            ReviewView()
                .tabItem { Label("Review", systemImage: "arrow.triangle.2.circlepath") }
                .tag(3)
            FocusView()
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(4)
        }
        .tint(Color.themeTextPrimary)
        .onOpenURL { url in
            if url.host == "weekly-review" {
                selectedTab = 3
            } else if url.host == "daily-briefing" {
                selectedTab = 0
            } else if url.host == "inbox" {
                selectedTab = 1
            }
        }
        .onAppear {
            let destination = UserDefaults.standard.string(forKey: WoolModelContainer.pendingDestinationKey)
            if destination == "weekly-review" || destination == "focus" {
                selectedTab = destination == "weekly-review" ? 3 : 4
                UserDefaults.standard.removeObject(forKey: WoolModelContainer.pendingDestinationKey)
            }
        }
    }

    private var todayTabSymbol: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "sunrise.fill" }
        if hour < 18 { return "sun.max.fill" }
        return "moon.stars.fill"
    }
}

private struct FocusView: View {
    var body: some View {
        NavigationStack {
            iOSContentView()
        }
        .accessibilityIdentifier("focus-tab-content")
    }
}

private struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Area.createdAt) private var areas: [Area]
    @State private var showingCapture = false
    @State private var briefingResult: DailyBriefingResult?
    @State private var briefingPresentation: DailyBriefingPresentation?
    @State private var briefingCacheKey = ""
    @State private var selectedAreaFilter: WorkspaceMetrics.AreaFilter = .all
    @State private var showingSettings = false

    private var todayTasks: [TaskItem] {
        let actions = tasks.filter { task in
            guard task.status == .nextAction else { return false }
            if let dueDate = task.dueDate {
                return Calendar.current.isDateInToday(dueDate)
            }
            return true
        }
        return WorkspaceMetrics.tasks(matching: selectedAreaFilter, areas: areas, from: actions)
    }

    private var overdueTasks: [TaskItem] {
        let actions = tasks.filter { task in
            task.status == .nextAction && task.dueDate.map { $0 < .now && !Calendar.current.isDateInToday($0) } == true
        }
        return WorkspaceMetrics.tasks(matching: selectedAreaFilter, areas: areas, from: actions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WorkspaceStyle.sectionSpacing) {
                    Text("Make space for what matters.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.themeTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    TodayBriefingCard(
                        overdueCount: overdueTasks.count,
                        dueTodayCount: todayTasks.filter { $0.dueDate != nil }.count,
                        waitingCount: tasks.filter { $0.status == .waitingFor }.count
                    )

                    Button { showingCapture = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(Color.themeButtonBackground)
                                .background(Color.white.opacity(0.82), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Capture an idea")
                                    .font(.headline.weight(.semibold))
                                Text("Get it out of your head")
                                    .font(.body)
                                    .foregroundStyle(Color.white.opacity(0.86))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.86))
                        }
                        .foregroundStyle(Color.white)
                        .padding(16)
                        .background(Color.themeButtonBackground, in: RoundedRectangle(cornerRadius: WorkspaceStyle.heroCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture an idea")
                    .accessibilityIdentifier(
                        WoolModelContainer.isTestingProcess
                            ? "home-capture-ui-testing"
                            : "home-capture-button"
                    )

                    AreaFilterChips(areas: areas, selection: $selectedAreaFilter)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next up")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.themeTextPrimary)

                        if todayTasks.isEmpty {
                            EmptyState(icon: "sparkles", title: "Your day is clear", message: "Capture something new or enjoy the space.")
                        } else {
                            ForEach(todayTasks.prefix(3)) { task in
                                TaskListItem(task: task)
                            }
                        }

                        NavigationLink {
                            TaskListsView(initialStatus: .nextAction)
                        } label: {
                            HStack {
                                Text("See all next actions")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(Color.themeTextPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("today-see-all-next-actions")
                    }
                }
                .padding(20)
                .padding(.bottom, WorkspaceStyle.controlHeight + 16)
            }
            .background(TabBackground(tint: Color.themeAccent).ignoresSafeArea())
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: areas.map(\.id)) { _, areaIDs in
                if case .area(let selectedID) = selectedAreaFilter, !areaIDs.contains(selectedID) {
                    selectedAreaFilter = .all
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("workspace-settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let key = briefingKey
                            if briefingCacheKey != key {
                                briefingResult = await DailyBriefingService.shared.makeBriefing(
                                    tasks: tasks,
                                    isFirstRun: tasks.isEmpty && !UserDefaults.standard.bool(forKey: "wool.hasGeneratedBriefing")
                                )
                                briefingCacheKey = key
                                UserDefaults.standard.set(true, forKey: "wool.hasGeneratedBriefing")
                            }
                            if let briefingResult {
                                briefingPresentation = DailyBriefingPresentation(result: briefingResult)
                            }
                        }
                    } label: { Image(systemName: "sparkles") }
                    .accessibilityLabel("Generate daily briefing")
                    .accessibilityIdentifier("daily-briefing-button")
                }
            }
            .sheet(isPresented: $showingCapture) { CaptureSheet(defaultStatus: .inbox) }
            .sheet(item: $briefingPresentation) { presentation in
                DailyBriefingView(result: presentation.result)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var briefingKey: String {
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let taskState = tasks.map {
            "\($0.id.uuidString):\($0.statusRawValue):\($0.dueDate?.timeIntervalSince1970 ?? 0):\($0.updatedAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        return "\(day)|\(DailyBriefingService.shared.calendarAccessCacheKey)|\(taskState)"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
}

private struct DailyBriefingPresentation: Identifiable {
    let id = UUID()
    let result: DailyBriefingResult
}

private struct TodayBriefingCard: View {
    let overdueCount: Int
    let dueTodayCount: Int
    let waitingCount: Int

    private var summary: String {
        if overdueCount > 0 {
            return "\(overdueCount) overdue \(overdueCount == 1 ? "action needs" : "actions need") your attention."
        }
        if dueTodayCount > 0 {
            return "\(dueTodayCount) \(dueTodayCount == 1 ? "action is" : "actions are") ready for today."
        }
        if waitingCount > 0 {
            return "Nothing is due today. \(waitingCount) \(waitingCount == 1 ? "item is" : "items are") waiting for a follow-up."
        }
        return "Your day is clear. Choose an action or enjoy the space."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today at a glance")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.themeTextPrimary)

            Text(summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                row("Overdue", count: overdueCount, symbol: "exclamationmark.circle.fill", tint: .orange)
                Divider().padding(.leading, 44)
                row("Due today", count: dueTodayCount, symbol: "calendar", tint: .blue)
                Divider().padding(.leading, 44)
                row("Waiting", count: waitingCount, symbol: "hourglass", tint: .purple)
            }
            .padding(.horizontal, 12)
            .background(Color.themeBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: WorkspaceStyle.compactCornerRadius, style: .continuous))
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: WorkspaceStyle.cardCornerRadius, style: .continuous))
        .accessibilityIdentifier("today-orientation-summary")
    }

    private func row(_ title: String, count: Int, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
            Spacer(minLength: 8)
            Text(count, format: .number)
                .font(.headline.weight(.semibold).monospacedDigit())
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyBriefingView: View {
    let result: DailyBriefingResult
    @State private var showingAllCalendarEvents = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if result.sections.isFirstRun {
                        emptyCard(icon: "sparkles", title: "Start with a thought", message: result.plainText)
                        calendarSection
                    } else if !result.sections.hasWork {
                        emptyCard(icon: "checkmark.seal.fill", title: "All clear", message: result.plainText)
                        calendarSection
                    } else {
                        if let narrative = result.narrative {
                            Text(narrative)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.themeTextPrimary)
                                .padding(16)
                                .background(Color.themeAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        if let summary = result.summaryText {
                            Text(summary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.themeTextPrimary)
                                .padding(.horizontal, 4)
                                .accessibilityIdentifier("daily-briefing-summary")
                        }
                        if !result.sections.dueToday.isEmpty { itemSection("Due today", icon: "sun.max.fill", items: result.sections.dueToday, tint: .blue, accessibilityIdentifier: "daily-briefing-due-today") }
                        if !result.sections.overdue.isEmpty { itemSection("Overdue", icon: "exclamationmark.triangle.fill", items: result.sections.overdue, tint: .orange, accessibilityIdentifier: "daily-briefing-overdue") }
                        if !result.sections.waiting.isEmpty { itemSection("Check on this", icon: "clock.badge.questionmark", items: result.sections.waiting, tint: .purple, accessibilityIdentifier: "daily-briefing-waiting") }
                        if !result.sections.upNext.isEmpty { itemSection("Up next", icon: "arrow.forward.circle.fill", items: result.sections.upNext, tint: .teal, accessibilityIdentifier: "daily-briefing-up-next") }
                        calendarSection
                    }
                }
                .padding(20)
            }
            .background(Color.themeBackground.ignoresSafeArea())
            .navigationTitle("Daily briefing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func emptyCard(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.themeTextPrimary)
            Text(title).font(.title3.weight(.bold))
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func itemSection(_ title: String, icon: String, items: [DailyBriefingItem], tint: Color, accessibilityIdentifier: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(tint)
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Circle().fill(tint.opacity(0.18)).frame(width: 28, height: 28).overlay { Image(systemName: "circle").font(.caption).foregroundStyle(tint) }
                    Text(item.title).font(.subheadline.weight(.medium))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var calendarSection: some View {
        let events = result.sections.calendarEvents
        guard !events.isEmpty else { return AnyView(EmptyView()) }
        let allDay = result.sections.allDayCalendarEvents
        let timed = result.sections.timedCalendarEvents
        let visibleTimed = showingAllCalendarEvents ? timed : Array(timed.prefix(10))
        return AnyView(VStack(alignment: .leading, spacing: 10) {
            Label("Calendar", systemImage: "calendar").font(.headline).foregroundStyle(.green)
            if !allDay.isEmpty {
                Text("All day").font(.subheadline.weight(.semibold)).accessibilityIdentifier("daily-briefing-calendar-all-day")
                ForEach(allDay) { event in
                    calendarEventRow(event, isAllDay: true)
                }
            }
            if !timed.isEmpty {
                Text("Schedule").font(.subheadline.weight(.semibold)).accessibilityIdentifier("daily-briefing-calendar-timed")
                ForEach(visibleTimed) { event in
                    calendarEventRow(event, isAllDay: false)
                }
                if timed.count > 10 {
                    Button(showingAllCalendarEvents ? "Show less" : "Show all \(timed.count) events") {
                        showingAllCalendarEvents.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("daily-briefing-calendar-show-all")
                }
            }
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("daily-briefing-calendar"))
    }

    private func calendarEventRow(_ event: DailyBriefingEvent, isAllDay: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isAllDay ? "sun.max.fill" : "calendar")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if !isAllDay {
                    Text(event.startDate, style: .time)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(event.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("daily-briefing-calendar-event-\(event.id)")
    }
}

private struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Area.createdAt) private var areas: [Area]
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showingCapture = false
    @State private var isTriaging = false
    @State private var triageNotice = ""
    @State private var showingTriageNotice = false
    @State private var triagedTaskIDs: [UUID] = []
    @State private var showingTriageResults = false
    @State private var selectedAreaFilter: WorkspaceMetrics.AreaFilter = .all

    private var inboxTasks: [TaskItem] { tasks.filter { $0.status == .inbox } }
    private var visibleTasks: [TaskItem] {
        let searched = InboxBehavior.filteredTasks(inboxTasks, query: searchText)
        return WorkspaceMetrics.tasks(matching: selectedAreaFilter, areas: areas, from: searched)
    }
    private var triagedTasks: [TaskItem] { tasks.filter { triagedTaskIDs.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inboxHeader
                    if showingSearch {
                        InboxSearchField(text: $searchText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    AreaFilterChips(areas: areas, selection: $selectedAreaFilter)
                    if visibleTasks.isEmpty {
                        EmptyState(
                            icon: searchText.isEmpty ? "tray" : "magnifyingglass",
                            title: searchText.isEmpty ? "Inbox is clear" : "No matching captures",
                            message: searchText.isEmpty ? "A quiet mind starts with one small capture." : "Try a different word or clear your search."
                        )
                        .padding(16)
                        .background(Color.themeCardBackground.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        captureCard
                        triageCard
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(searchText.isEmpty ? "To process" : "Results")
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text(visibleTasks.count, format: .number)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LazyVStack(spacing: 10) {
                            ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                                if index == 3 {
                                    triageCard
                                    Text("More captures")
                                        .font(.headline.weight(.bold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                inboxTaskRow(task)
                            }
                            if visibleTasks.count <= 3 {
                                triageCard
                            }
                        }
                    }

                    NavigationLink { TaskListsView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.3.group.fill")
                                .foregroundStyle(Color.themeTextPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.themePrimary.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Browse Lists").font(.subheadline.weight(.semibold))
                                Text("Next Actions, Waiting For, and Someday / Maybe")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("browse-lists")
                }
                .padding(.horizontal, WorkspaceStyle.contentPadding)
                .padding(.vertical, 16)
                .padding(.bottom, WorkspaceStyle.controlHeight + 16)
            }
            .background(TabBackground(tint: Color.themePrimary).ignoresSafeArea())
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: areas.map(\.id)) { _, areaIDs in
                if case .area(let selectedID) = selectedAreaFilter, !areaIDs.contains(selectedID) {
                    selectedAreaFilter = .all
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showingSearch.toggle()
                        }
                    } label: {
                        Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                    }
                    .accessibilityLabel(showingSearch ? "Close search" : "Search inbox")
                    .accessibilityIdentifier("inbox-search-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCapture = true } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Capture a thought")
                    .accessibilityIdentifier("inbox-capture-button")
                }
            }
            .sheet(isPresented: $showingCapture) { CaptureSheet(defaultStatus: .inbox) }
            .sheet(isPresented: $showingTriageResults) { TriageResultsSheet(tasks: triagedTasks) }
            .alert("Inbox triaged", isPresented: $showingTriageNotice) { Button("Done") {} } message: { Text(triageNotice) }
            .onAppear {
                InboxAgingReminderService.shared.checkAndScheduleIfNeeded(inboxTasks: inboxTasks)
            }
        }
    }

    private var inboxHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Everything you’ve captured, ready when you are.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text("To process")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(inboxTasks.count, format: .number)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.themeTextPrimary)
                    .accessibilityLabel("\(inboxTasks.count) inbox items")
            }
        }
    }

    private var captureCard: some View {
        Button { showingCapture = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.themePrimary.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Capture a thought")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Get it out of your head in one tap")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(12)
            .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture a thought")
        .accessibilityIdentifier("inbox-empty-capture-button")
    }

    private var triageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ready to sort it out?", systemImage: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.themeTextPrimary)
            Text("Let on-device intelligence suggest what comes next.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await triageInbox() } } label: {
                HStack(spacing: 8) {
                    if isTriaging {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                        Text("Triage")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.themeButtonBackground)
            .disabled(isTriaging || inboxTasks.isEmpty)
            .accessibilityLabel("Triage")
            .accessibilityIdentifier("inbox-triage-button")
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func inboxTaskRow(_ task: TaskItem) -> some View {
        TaskListItem(task: task, identifierPrefix: "inbox-item")
            .contextMenu {
                Button {
                    task.status = .nextAction
                    try? modelContext.save()
                    TaskDueNotificationService.shared.sync(task: task)
                } label: {
                    Label("Make next action", systemImage: "arrow.right.circle")
                }
                Button(role: .destructive) {
                    let taskID = task.id
                    modelContext.delete(task)
                    try? modelContext.save()
                    TaskDueNotificationService.shared.cancel(taskID: taskID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private func triageInbox() async {
        isTriaging = true
        let movedTasks = await InboxTriageService.triage(inboxTasks)
        try? modelContext.save()
        isTriaging = false
        triageNotice = InboxBehavior.triageSummary(movedCount: movedTasks.count)
        triagedTaskIDs = movedTasks.map(\.id)
        if movedTasks.isEmpty {
            showingTriageNotice = true
        } else {
            showingTriageResults = true
        }
    }
}

private struct InboxSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search captures", text: $text)
                .frame(minHeight: 44)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("Search captures")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.themeBorder, lineWidth: 1)
        }
    }
}

private struct TaskListItem: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    let identifierPrefix: String

    init(task: TaskItem, identifierPrefix: String = "task-row") {
        self.task = task
        self.identifierPrefix = identifierPrefix
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                task.status = .completed
                try? modelContext.save()
                TaskDueNotificationService.shared.sync(task: task)
            } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .completed ? Color.themePrimary : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark capture complete")

            NavigationLink { WorkspaceTaskDetailView(task: task) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 6) {
                        Text(captureDateLabel)
                        if let dueDate = task.dueDate {
                            Text("Due \(dueDateLabel(for: dueDate))")
                        }
                        if let area = primaryArea {
                            Text(area.name)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.themePrimary.opacity(0.14), in: Capsule())
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(Color.themeCardBackground.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.themePrimary.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix)-\(task.id.uuidString)")
    }

    private var primaryArea: Area? {
        task.areas?.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.first
    }

    private var captureDateLabel: String {
        if Date.now.timeIntervalSince(task.createdAt) < 60 { return "Just now" }
        let calendar = Calendar.current
        if calendar.isDateInToday(task.createdAt) { return "Today" }
        if calendar.isDateInYesterday(task.createdAt) { return "Yesterday" }
        return task.createdAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private func dueDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct TriageResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [TaskItem]

    private let statuses: [Status] = [.nextAction, .waitingFor, .somedayMaybe]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Nothing was deleted. Each capture now has a organized home.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(statuses, id: \.self) { status in
                    let matchingTasks = InboxBehavior.organizedTasks(tasks, status: status)
                    if !matchingTasks.isEmpty {
                        Section(status.displayName) {
                            ForEach(matchingTasks) { task in
                                NavigationLink { WorkspaceTaskDetailView(task: task) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title).font(.body.weight(.medium))
                                        if let dueDate = task.dueDate {
                                            Text("Due \(dueDate, style: .date)")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .accessibilityIdentifier("triage-result-\(status.rawValue)-\(task.id.uuidString)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sorted for you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("All lists") { TaskListsView() }
                        .accessibilityIdentifier("triage-results-all-lists")
                }
            }
        }
    }
}

private struct TaskListsView: View {
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selectedStatus: Status

    private let statuses: [Status] = [.nextAction, .waitingFor, .somedayMaybe]

    init(initialStatus: Status = .nextAction) {
        _selectedStatus = State(initialValue: initialStatus)
    }

    private var visibleTasks: [TaskItem] {
        InboxBehavior.organizedTasks(tasks, status: selectedStatus)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TabDescription(listDescription)

                Picker("List", selection: $selectedStatus) {
                    Text("Next").tag(Status.nextAction)
                    Text("Waiting").tag(Status.waitingFor)
                    Text("Someday").tag(Status.somedayMaybe)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("list-picker")

                if visibleTasks.isEmpty {
                    EmptyState(icon: emptySymbol, title: "Nothing here yet", message: emptyMessage)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleTasks) { task in
                            TaskListItem(task: task)
                                .padding(.horizontal, 4)
                                .accessibilityIdentifier("list-\(selectedStatus.rawValue)-\(task.id.uuidString)")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(TabBackground(tint: Color.themePrimary).ignoresSafeArea())
        .navigationTitle(selectedStatus.displayName)
        .navigationBarTitleDisplayMode(.large)
    }

    private var listDescription: String {
        switch selectedStatus {
        case .nextAction: "Every actionable step, including work scheduled for later."
        case .waitingFor: "Promises, replies, and outcomes you are waiting on."
        case .somedayMaybe: "Ideas worth keeping without making a commitment today."
        default: ""
        }
    }

    private var emptySymbol: String {
        switch selectedStatus {
        case .nextAction: "checklist"
        case .waitingFor: "hourglass"
        case .somedayMaybe: "sparkles"
        default: "tray"
        }
    }

    private var emptyMessage: String {
        switch selectedStatus {
        case .nextAction: "Clarify an Inbox capture or add an action directly."
        case .waitingFor: "Move a capture here when someone else has the next move."
        case .somedayMaybe: "Keep an idea here until it becomes a real commitment."
        default: ""
        }
    }
}

private struct ProjectsView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Query private var tasks: [TaskItem]
    @Query(sort: \Area.createdAt) private var areas: [Area]
    @State private var showingNewProject = false
    @State private var filter: WorkspaceFilter = .active
    @State private var selectedAreaFilter: WorkspaceMetrics.AreaFilter = .all

    private var visibleProjects: [Project] {
        let filtered = WorkspaceMetrics.projects(projects, matching: filter)
        guard selectedAreaFilter != .all else { return filtered }
        return filtered.filter { project in
            !WorkspaceMetrics.tasks(matching: selectedAreaFilter, areas: areas, from: tasks.filter { $0.project?.id == project.id }).isEmpty
        }
    }

    private var portfolioSummary: ProjectPortfolioSummary {
        WorkspaceMetrics.projectPortfolioSummary(projects: projects, tasks: tasks)
    }

    private var sectionTitle: String {
        switch filter {
        case .active: "Current outcomes"
        case .completed: "Finished outcomes"
        case .archived: "Set aside"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Turn intentions into outcomes.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    WorkspacePicker(selection: $filter)
                    AreaFilterChips(areas: areas, selection: $selectedAreaFilter)

                    HStack(alignment: .firstTextBaseline) {
                        Text(sectionTitle)
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text(visibleProjects.count, format: .number)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(visibleProjects.count) projects")
                    }
                    .padding(.top, 4)

                    if visibleProjects.isEmpty {
                        ProjectsEmptyState(filter: filter) {
                            showingNewProject = true
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visibleProjects) { project in
                                NavigationLink { ProjectDetailView(project: project, tasks: tasks) } label: {
                                    ProjectCard(project: project, tasks: tasks)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("project-card-\(project.id.uuidString)")
                            }
                        }
                    }

                    ProjectPortfolioHeader(summary: portfolioSummary)
                }
                .padding(20)
                .padding(.bottom, WorkspaceStyle.controlHeight + 16)
            }
            .background(TabBackground(tint: Color.themePrimary).ignoresSafeArea())
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: areas.map(\.id)) { _, areaIDs in
                if case .area(let selectedID) = selectedAreaFilter, !areaIDs.contains(selectedID) {
                    selectedAreaFilter = .all
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewProject = true } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                    }
                        .accessibilityLabel("Add project")
                        .accessibilityIdentifier("add-project")
                }
            }
            .sheet(isPresented: $showingNewProject) { NewProjectSheet() }
        }
    }
}

private struct ProjectPortfolioHeader: View {
    let summary: ProjectPortfolioSummary

    private var statusText: String {
        guard summary.active > 0 else { return "Ready for a fresh outcome" }
        guard summary.needsNextAction > 0 else { return "Every project has a next action" }
        let noun = summary.needsNextAction == 1 ? "project needs" : "projects need"
        return "\(summary.needsNextAction) \(noun) a next action"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OUTCOMES")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.themeTextPrimary.opacity(0.72))
                Text("Move what matters forward.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)
                Text("Turn multi-step commitments into clear, finishable outcomes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                ProjectPortfolioMetric(value: summary.active, label: "Active", symbol: "circle.grid.2x2.fill")
                Divider().frame(height: 38)
                ProjectPortfolioMetric(value: summary.moving, label: "Moving", symbol: "arrow.up.right")
                Divider().frame(height: 38)
                ProjectPortfolioMetric(value: summary.needsNextAction, label: "Needs action", symbol: "exclamationmark")
            }

            Label(statusText, systemImage: summary.needsNextAction == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(summary.needsNextAction == 0 ? Color.themeTextPrimary : Color.orange)
                .accessibilityIdentifier("project-portfolio-status")
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: WorkspaceStyle.cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-portfolio-header")
    }
}

private struct ProjectPortfolioMetric: View {
    let value: Int
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(value, format: .number)
                    .font(.title3.weight(.bold).monospacedDigit())
            } icon: {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)
            }
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("project-portfolio-metric-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

private struct ProjectsEmptyState: View {
    let filter: WorkspaceFilter
    let createProject: () -> Void

    private var content: (icon: String, title: String, message: String) {
        switch filter {
        case .active: ("scope", "Choose an outcome", "Name something meaningful you want to make true, then give it one clear next action.")
        case .completed: ("checkmark.circle", "No finished outcomes yet", "Completed projects will collect here as a record of your momentum.")
        case .archived: ("archivebox", "Nothing set aside", "Projects you archive will stay safely out of the way here.")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: content.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.themeTextPrimary)
                .frame(width: 54, height: 54)
                .background(Color.themePrimary.opacity(0.20), in: Circle())
            VStack(spacing: 6) {
                Text(content.title).font(.headline.weight(.bold))
                Text(content.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if filter == .active {
                Button(action: createProject) {
                    Label("Create a project", systemImage: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.themeButtonForeground)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color.themeButtonBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("empty-add-project")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct AreasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Area.createdAt) private var areas: [Area]
    @Query private var tasks: [TaskItem]
    @State private var showingNewArea = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TabDescription("Keep the parts of life that never truly leave your care in view.")
                    if areas.isEmpty {
                        EmptyState(icon: "circle.grid.2x2", title: "No areas yet", message: "Add a responsibility you want to keep healthy.").padding(.top, 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(areas) { area in
                                NavigationLink { AreaDetailView(area: area, tasks: tasks) } label: {
                                    AreaCard(area: area, tasks: WorkspaceMetrics.tasks(in: area, from: tasks))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("area-card-\(area.id.uuidString)")
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(area)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityIdentifier("delete-area-\(area.name.lowercased().replacingOccurrences(of: " ", with: "-"))")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(TabBackground(tint: Color.themeAccent).ignoresSafeArea())
            .navigationTitle("Areas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewArea = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add area")
                        .accessibilityIdentifier("add-area")
                }
            }
            .sheet(isPresented: $showingNewArea) { NewAreaSheet() }
        }
    }

    private func delete(_ area: Area) {
        for task in tasks {
            task.areas = task.areas?.filter { $0.id != area.id }
        }
        modelContext.delete(area)
        try? modelContext.save()
    }
}

struct TabBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            Color.themeBackground
            RadialGradient(
                colors: [tint.opacity(WorkspaceStyle.backgroundGlowOpacity), .clear],
                center: .top,
                startRadius: 20,
                endRadius: WorkspaceStyle.backgroundGlowRadius
            )
        }
    }
}

/// Shared visual language for the primary workspace tabs. Focus and Projects
/// are the reference surfaces; keeping these values centralized prevents each
/// tab from slowly developing its own spacing and shape vocabulary.
enum WorkspaceStyle {
    static let contentPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 14
    static let compactCornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let heroCornerRadius: CGFloat = 24
    static let backgroundGlowOpacity: Double = 0.10
    static let backgroundGlowRadius: CGFloat = 430
    static let controlHeight: CGFloat = 48
}

struct NavigationTitle: View {
    let eyebrow: String?
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.headline.weight(.bold))
                .lineLimit(1)
        }
        .frame(maxWidth: 220, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct TabDescription: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WorkspacePicker: View {
    @Binding var selection: WorkspaceFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceFilter.allCases) { filter in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selection == filter ? .primary : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 6)
                        .background(selection == filter ? Color.themeCardBackground : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workspace-filter-\(filter.rawValue)")
            }
        }
        .padding(4)
        .background(Color.themeCardBackground.opacity(0.62), in: Capsule())
    }
}

private struct AreaFilterChips: View {
    let areas: [Area]
    @Binding var selection: WorkspaceMetrics.AreaFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "All areas", symbol: "line.3.horizontal.decrease.circle", isSelected: selection == .all) {
                    selection = .all
                }
                filterButton(title: "Uncategorized", symbol: "questionmark.circle", isSelected: selection == .uncategorized) {
                    selection = .uncategorized
                }
                ForEach(areas) { area in
                    filterButton(title: area.name, symbol: "circle.fill", isSelected: selection == .area(area.id)) {
                        selection = .area(area.id)
                    }
                }
            }
        }
        .accessibilityIdentifier("area-filter-chips")
    }

    private func filterButton(title: String, symbol: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.themeTextPrimary : .secondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 44)
                .background(isSelected ? Color.themePrimary.opacity(0.22) : Color.themeCardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("area-filter-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityLabel("Filter by \(title)")
    }
}

private struct ProjectCard: View {
    let project: Project
    let tasks: [TaskItem]
    private var projectTasks: [TaskItem] { tasks.filter { $0.project?.id == project.id } }
    private var metrics: ProjectMetrics { WorkspaceMetrics.projectMetrics(tasks: projectTasks) }

    private var nextAction: TaskItem? {
        projectTasks
            .filter { $0.status == .nextAction }
            .sorted {
                if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
                return $0.sortOrder < $1.sortOrder
            }
            .first
    }

    private var state: (title: String, symbol: String, tint: Color) {
        if project.isArchived { return ("Set aside", "archivebox.fill", .secondary) }
        if project.status == .completed { return ("Complete", "checkmark.circle.fill", Color.themeTextPrimary) }
        if nextAction != nil { return ("Moving", "arrow.up.right.circle.fill", Color.themeTextPrimary) }
        return ("Needs action", "exclamationmark.circle.fill", .orange)
    }

    private var actionText: String {
        if let nextAction { return "Next · \(nextAction.title)" }
        if project.status == .completed { return "Outcome complete" }
        if project.isArchived { return "Project set aside" }
        return "Add a clear next action"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(project.desiredOutcome.isEmpty ? "Define what done looks like" : project.desiredOutcome)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Label(state.title, systemImage: state.symbol)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.tint)
                    .frame(width: 34, height: 34)
                    .background(state.tint.opacity(0.11), in: Circle())
                    .accessibilityLabel(state.title)
            }

            ProgressView(value: metrics.progress)
                .tint(project.status == .completed ? Color.themeTextPrimary.opacity(0.65) : Color.themeAccent)
                .accessibilityIdentifier("project-progress-\(project.id.uuidString)")

            HStack(spacing: 8) {
                Image(systemName: nextAction == nil ? "arrow.turn.down.right" : "arrow.right")
                    .font(.caption2.weight(.bold))
                Text(actionText)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(metrics.total == 0 ? "No actions" : "\(metrics.completed)/\(metrics.total)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(nextAction == nil && project.status == .active && !project.isArchived ? Color.orange : .secondary)
        }
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(nextAction == nil && project.status == .active && !project.isArchived ? Color.orange.opacity(0.20) : Color.themeBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct AreaCard: View {
    let area: Area; let tasks: [TaskItem]
    var body: some View { HStack(spacing: 14) { Circle().fill(Color.orange.opacity(0.14)).frame(width: 44, height: 44).overlay(Image(systemName: "circle.grid.2x2.fill").font(.subheadline).foregroundStyle(.orange)); VStack(alignment: .leading, spacing: 4) { Text(area.name).font(.headline); Text(area.notes.isEmpty ? "Ongoing responsibility" : area.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); VStack(alignment: .trailing, spacing: 3) { Text("\(tasks.filter { $0.status != .completed }.count)").font(.title3.weight(.bold).monospacedDigit()); Text("open").font(.caption2).foregroundStyle(.secondary) } }.padding(16).background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) }
}

private struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    let tasks: [TaskItem]
    @State private var showingCompletionWarning = false
    @State private var showingArchiveConfirmation = false
    @State private var showingNewAction = false

    private var projectTasks: [TaskItem] { tasks.filter { $0.project?.id == project.id } }
    private var metrics: ProjectMetrics { WorkspaceMetrics.projectMetrics(tasks: projectTasks) }
    private var openTasks: [TaskItem] {
        projectTasks
            .filter { $0.status != .completed && $0.status != .cancelled }
            .sorted(by: actionSort)
    }
    private var completedTasks: [TaskItem] {
        projectTasks
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }
    private var nextAction: TaskItem? { openTasks.first { $0.status == .nextAction } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProjectOutcomeCard(project: project, metrics: metrics)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Next action", detail: nextAction == nil ? "Choose the next visible move" : "Keep momentum clear")
                    if let nextAction {
                        ProjectActionRow(task: nextAction, isEmphasized: true, toggle: { toggle(nextAction) })
                            .accessibilityIdentifier("project-detail-next-action")
                    } else {
                        Button { showingNewAction = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 38, height: 38)
                                    .background(Color.orange.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("No next action yet").font(.headline)
                                    Text("Add one concrete move to restart momentum.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(Color.themeTextPrimary)
                            }
                            .padding(15)
                            .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("project-detail-next-action-empty")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionTitle(title: "Open actions", detail: openTasks.isEmpty ? "Nothing open" : "\(openTasks.count) remaining")
                        Spacer()
                        Button { showingNewAction = true } label: {
                            Label("Add action", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.themeTextPrimary)
                        .accessibilityLabel("Add action")
                        .accessibilityIdentifier("add-project-action")
                    }

                    if openTasks.isEmpty {
                        ProjectEmptyActionsCard(addAction: { showingNewAction = true })
                    } else {
                        VStack(spacing: 10) {
                            ForEach(openTasks.filter { $0.id != nextAction?.id }) { task in
                                ProjectActionRow(task: task, isEmphasized: false, toggle: { toggle(task) })
                            }
                        }
                    }
                }
                .accessibilityIdentifier("project-detail-open-actions")

                if !completedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Completed", detail: "\(completedTasks.count) finished")
                        VStack(spacing: 10) {
                            ForEach(completedTasks) { task in
                                ProjectActionRow(task: task, isEmphasized: false, toggle: { toggle(task) })
                            }
                        }
                    }
                    .accessibilityIdentifier("project-detail-completed-actions")
                }

                if !project.isArchived {
                    Button(project.status == .completed ? "Reopen project" : "Complete project") {
                        if project.status != .completed && !WeeklyReviewService.shared.canComplete(project) {
                            showingCompletionWarning = true
                        } else {
                            project.status = project.status == .completed ? .active : .completed
                            try? modelContext.save()
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(project.status == .completed ? Color.themeTextPrimary : Color.themeButtonForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        project.status == .completed ? Color.themeCardBackground : Color.themeButtonBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("project-completion-action")
                }
            }
            .padding(20)
        }
        .background(TabBackground(tint: Color.themePrimary).ignoresSafeArea())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if project.isArchived {
                        Button("Restore project", systemImage: "arrow.uturn.backward") {
                            project.restore()
                            try? modelContext.save()
                        }
                        .accessibilityIdentifier("restore-project")
                    } else {
                        Button("Archive project", systemImage: "archivebox") {
                            showingArchiveConfirmation = true
                        }
                        .accessibilityIdentifier("archive-project")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Project actions")
                .accessibilityIdentifier("project-actions-menu")
            }
        }
        .alert("Open actions remain", isPresented: $showingCompletionWarning) {
            Button("Keep working", role: .cancel) { }
        } message: {
            Text("Complete or reassign all Next Action and Waiting For tasks before completing this project.")
        }
        .alert("Archive project?", isPresented: $showingArchiveConfirmation) {
            Button("Archive project", role: .destructive) {
                project.archive()
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(projectTasks.isEmpty ? "This empty project will be hidden until you restore it." : "Its linked actions will stay attached and can be restored with the project.")
        }
        .sheet(isPresented: $showingNewAction) {
            NewProjectActionSheet(project: project)
        }
    }

    private func actionSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.status != rhs.status { return lhs.status == .nextAction }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt < rhs.createdAt
    }

    private func toggle(_ task: TaskItem) {
        task.status = task.status == .completed ? .nextAction : .completed
        try? modelContext.save()
        TaskDueNotificationService.shared.sync(task: task)
    }
}

private struct ProjectOutcomeCard: View {
    let project: Project
    let metrics: ProjectMetrics

    private var state: (label: String, symbol: String, tint: Color) {
        if project.isArchived { return ("Set aside", "archivebox.fill", .secondary) }
        if project.status == .completed { return ("Complete", "checkmark.circle.fill", Color.themeTextPrimary) }
        return ("Active", "arrow.up.right.circle.fill", Color.themeTextPrimary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("OUTCOME")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.themeTextPrimary.opacity(0.72))
                Spacer()
                Label(state.label, systemImage: state.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.tint)
            }
            Text(project.desiredOutcome.isEmpty ? "Define the outcome this project is moving toward." : project.desiredOutcome)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: metrics.progress)
                .tint(project.status == .completed ? Color.themeTextPrimary.opacity(0.65) : Color.themeAccent)
                .accessibilityIdentifier("project-detail-progress")
            HStack {
                Text("\(metrics.completed) complete")
                Spacer()
                Text("\(max(metrics.total - metrics.completed, 0)) remaining")
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-detail-outcome")
    }
}

private struct SectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline.weight(.bold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ProjectActionRow: View {
    let task: TaskItem
    let isEmphasized: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .completed ? Color.themeTextPrimary : isEmphasized ? Color.themeTextPrimary : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .completed ? "Reopen \(task.title)" : "Complete \(task.title)")

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.body.weight(isEmphasized ? .semibold : .regular))
                    .foregroundStyle(task.status == .completed ? .secondary : .primary)
                    .strikethrough(task.status == .completed, color: .secondary)
                HStack(spacing: 6) {
                    Text(task.status.displayName)
                    if let dueDate = task.dueDate { Text("Due \(dueDate, style: .date)") }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(15)
        .background(
            isEmphasized ? Color.themePrimary.opacity(0.10) : Color.themeCardBackground,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isEmphasized ? Color.themePrimary.opacity(0.20) : Color.themeBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-task-\(task.id.uuidString)")
    }
}

private struct ProjectEmptyActionsCard: View {
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No open actions", systemImage: "checkmark.circle")
                .font(.headline)
            Text("Add the next concrete action, or complete the project if the outcome is already true.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Add an action", action: addAction)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("add-project-action-empty")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NewProjectActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var title = ""
    @State private var notes = ""

    private var normalizedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Next action") {
                    TextField("What is the next visible move?", text: $title)
                        .accessibilityIdentifier("new-project-action-title")
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("new-project-action-notes")
                }
            }
            .navigationTitle("Add action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let action = TaskItem(
                            title: normalizedTitle,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            status: .nextAction,
                            project: project
                        )
                        modelContext.insert(action)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(normalizedTitle.isEmpty)
                    .accessibilityIdentifier("save-project-action")
                }
            }
        }
    }
}

private struct AreaDetailView: View {
    let area: Area
    let tasks: [TaskItem]

    private var openTasks: [TaskItem] { WorkspaceMetrics.openTasks(in: area, from: tasks) }

    var body: some View {
        List {
            Section {
                Text(area.notes.isEmpty ? "An ongoing responsibility to keep healthy." : area.notes)
                    .font(.subheadline).foregroundStyle(.secondary)
            } header: { Text("Responsibility") }
            Section("Open actions") {
                if openTasks.isEmpty { Text("This area is clear").foregroundStyle(.secondary) }
                ForEach(openTasks) { task in
                    Label(task.title, systemImage: "circle")
                        .accessibilityIdentifier("area-task-\(task.id.uuidString)")
                }
            }
        }
        .navigationTitle(area.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyReview.weekStart, order: .reverse) private var reviews: [WeeklyReview]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]
    @Query(sort: \Area.createdAt) private var areas: [Area]
    @State private var review: WeeklyReview?
    @State private var reviewPrompt = ""
    @State private var showingReviewPrompt = false
    @State private var selectedStep: Int?

    private var inboxCount: Int { tasks.filter { $0.status == .inbox }.count }
    private var waitingCount: Int { tasks.filter { $0.status == .waitingFor }.count }
    private var openTaskCount: Int { tasks.filter { $0.status != .completed && $0.status != .cancelled }.count }
    private var projectsNeedingAction: [Project] { WeeklyReviewService.shared.projectsNeedingNextAction(projects) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let review {
                        if review.status == .inProgress {
                            ReviewSessionView(
                                review: review,
                                tasks: tasks,
                                projectsNeedingAction: projectsNeedingAction,
                                openTaskCount: openTaskCount,
                                selectedStep: $selectedStep,
                                advance: { item, skipped in advance(review, item: item, skipped: skipped) },
                                decide: { decision, task in decide(decision, task: task, review: review) }
                            )
                        } else {
                            ReviewCompletionView(review: review, openTaskCount: openTaskCount) {
                                startReview()
                            }
                        }
                    } else {
                        ReviewLandingView(
                            completedReviews: reviews.filter { $0.status == .completed || $0.status == .partial }.count,
                            streak: WeeklyReviewService.shared.reviewStreak(reviews),
                            inboxCount: inboxCount,
                            waitingCount: waitingCount,
                            projectsNeedingAction: projectsNeedingAction.count,
                            startReview: startReview
                        )
                    }

                    ReviewAreasLink(areaCount: areas.count)
                }
                .padding(20)
                .padding(.bottom, WorkspaceStyle.controlHeight + 16)
            }
            .background(TabBackground(tint: Color.themeAccent).ignoresSafeArea())
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let review else { return }
                        Task {
                            reviewPrompt = await OnDeviceIntelligenceService.shared.weeklyReviewPrompt(review: review, openTaskCount: openTaskCount)
                            showingReviewPrompt = true
                        }
                    } label: { Image(systemName: "sparkles") }
                    .disabled(review == nil)
                    .accessibilityLabel("Get a weekly review prompt")
                }
            }
            .alert("Review prompt", isPresented: $showingReviewPrompt) { Button("Done") {} } message: { Text(reviewPrompt) }
            .onAppear {
                let resumedReview = WeeklyReviewService.shared.resumeReview(from: reviews)
                let currentWeekReview = WeeklyReviewService.shared.review(forWeekContaining: .now, from: reviews)
                let completedReview = reviews.first { candidate in
                    let isCompleted = candidate.status == .completed
                    let isPartial = candidate.status == .partial
                    return isCompleted || isPartial
                }
                if let resumedReview {
                    review = resumedReview
                } else if let currentWeekReview {
                    review = currentWeekReview
                } else {
                    review = completedReview
                }
                if let review, review.status == .inProgress { WeeklyReviewService.shared.prepareStaleItems(tasks, for: review); try? modelContext.save() }
            }
        }
    }

    private func startReview() {
        // Only resume an in-progress review for the current week. A
        // partial/completed review must not be picked back up here, or
        // "Start a new review" would just reopen the one just finished.
        if let existing = WeeklyReviewService.shared.review(forWeekContaining: .now, from: reviews),
           existing.status == .inProgress {
            review = existing
        } else {
            let newReview = WeeklyReviewService.shared.makeWeeklyReview()
            modelContext.insert(newReview)
            for item in newReview.checklistItems ?? [] {
                item.review = newReview
                modelContext.insert(item)
            }
            review = newReview
        }
        if let review {
            WeeklyReviewService.shared.prepareStaleItems(tasks, for: review)
        }
        selectedStep = nil
        try? modelContext.save()
    }

    private func advance(_ review: WeeklyReview, item: WeeklyReviewItem, skipped: Bool) {
        let save = {
            WeeklyReviewService.shared.saveStep(review, step: item.sortOrder, skipped: skipped)
            if review.status != .inProgress {
                WeeklyReviewService.shared.finish(review, reviews: reviews.filter { $0.id != review.id })
            }
            selectedStep = nil
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            save()
        } else {
            withAnimation(.easeOut(duration: 0.18), save)
        }
        if let current = self.review {
            self.review = nil
            self.review = current
        }
        try? modelContext.save()
    }

    private func decide(_ decision: WeeklyReviewStaleDecision, task: TaskItem, review: WeeklyReview) {
        WeeklyReviewService.shared.decide(decision, for: task, review: review)
        try? modelContext.save()
        TaskDueNotificationService.shared.sync(task: task)
    }
}

private struct ReviewLandingView: View {
    let completedReviews: Int
    let streak: Int
    let inboxCount: Int
    let waitingCount: Int
    let projectsNeedingAction: Int
    let startReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your overview")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.themeTextPrimary)

                VStack(spacing: 0) {
                    ReviewReadinessRow(symbol: "tray.fill", title: "Inbox", value: inboxCount, detail: inboxCount == 0 ? "Clear" : "to clarify", tint: .orange)
                    Divider().padding(.leading, 48)
                    ReviewReadinessRow(symbol: "square.stack.3d.up.fill", title: "Projects", value: projectsNeedingAction, detail: projectsNeedingAction == 0 ? "Moving" : "need action", tint: Color.themeTextPrimary)
                    Divider().padding(.leading, 48)
                    ReviewReadinessRow(symbol: "hourglass", title: "Waiting", value: waitingCount, detail: waitingCount == 0 ? "Clear" : "to revisit", tint: .purple)
                }
                .background(Color.themeBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 0) {
                    ReviewMetric(value: completedReviews, label: "Reviews", symbol: "checkmark.circle.fill")
                    Divider().frame(height: 38)
                    ReviewMetric(value: streak, label: "Week streak", symbol: "flame.fill")
                }
            }
            .padding(16)
            .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("WEEKLY RESET")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.themeTextPrimary.opacity(0.72))
                    Text("Make space for the week ahead.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.themeTextPrimary)
                    Text("Close open loops, restore momentum, and choose what matters next.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: startReview) {
                    HStack {
                        Text("Start weekly review")
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.themeButtonForeground)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.themeButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start weekly review")
                .accessibilityIdentifier("start-weekly-review")
            }
            .padding(18)
            .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review-landing")
    }
}

private struct ReviewMetric: View {
    let value: Int
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(value, format: .number).font(.title3.weight(.bold).monospacedDigit())
            } icon: {
                Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(Color.themeTextPrimary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review-metric-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

private struct ReviewReadinessRow: View {
    let symbol: String
    let title: String
    let value: Int
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(value, format: .number)
                .font(.headline.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review-readiness-\(title.lowercased())")
    }
}

private struct ReviewSessionView: View {
    @Bindable var review: WeeklyReview
    let tasks: [TaskItem]
    let projectsNeedingAction: [Project]
    let openTaskCount: Int
    @Binding var selectedStep: Int?
    let advance: (WeeklyReviewItem, Bool) -> Void
    let decide: (WeeklyReviewStaleDecision, TaskItem) -> Void

    private var orderedItems: [WeeklyReviewItem] {
        (review.checklistItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var displayedIndex: Int {
        guard !orderedItems.isEmpty else { return 0 }
        return min(selectedStep ?? review.currentStep, orderedItems.count - 1)
    }

    private var displayedItem: WeeklyReviewItem? {
        orderedItems.first { $0.sortOrder == displayedIndex }
    }

    private var resolvedCount: Int { review.completedStepCount + review.skippedStepCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WEEKLY RESET")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.themeTextPrimary.opacity(0.72))
                        Text("Review in progress").font(.title3.weight(.bold))
                    }
                    Spacer()
                    Text("\(resolvedCount) of \(orderedItems.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(resolvedCount), total: Double(max(orderedItems.count, 1)))
                    .tint(Color.themeAccent)
            }
            .accessibilityIdentifier("weekly-review-progress")

            ReviewStepNavigator(
                items: orderedItems,
                displayedStep: displayedIndex,
                reviewCurrentStep: review.currentStep,
                selection: $selectedStep
            )

            if let displayedItem {
                ReviewStepCard(
                    item: displayedItem,
                    review: review,
                    tasks: tasks,
                    projectsNeedingAction: projectsNeedingAction,
                    openTaskCount: openTaskCount,
                    isCurrentStep: displayedItem.sortOrder == review.currentStep,
                    complete: { advance(displayedItem, false) },
                    skip: { advance(displayedItem, true) },
                    returnToCurrent: { selectedStep = nil },
                    decide: decide
                )
                .id(displayedItem.sortOrder)
                .transition(.opacity)
            }
        }
        .accessibilityIdentifier("review-session")
    }
}

private struct ReviewStepNavigator: View {
    let items: [WeeklyReviewItem]
    let displayedStep: Int
    let reviewCurrentStep: Int
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    selection = item.sortOrder
                } label: {
                    marker(for: item)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(item.sortOrder == displayedStep ? Color.themeButtonForeground : tint(for: item))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(item.sortOrder == displayedStep ? Color.themeButtonBackground : Color.themeCardBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title), \(status(for: item))")
                .accessibilityValue(status(for: item))
                .accessibilityIdentifier("review-step-navigator-\(item.sortOrder)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Review steps")
    }

    @ViewBuilder
    private func marker(for item: WeeklyReviewItem) -> some View {
        if item.isComplete {
            Image(systemName: "checkmark")
        } else if item.isSkipped {
            Image(systemName: "arrow.right")
        } else {
            Text(item.sortOrder + 1, format: .number)
        }
    }

    private func tint(for item: WeeklyReviewItem) -> Color {
        if item.isComplete { return Color.themeTextPrimary }
        if item.isSkipped { return .orange }
        return .secondary
    }

    private func status(for item: WeeklyReviewItem) -> String {
        if item.isComplete { return "Complete" }
        if item.isSkipped { return "Skipped" }
        return item.sortOrder == reviewCurrentStep ? "Current" : "Not reviewed"
    }
}

private struct ReviewStepCard: View {
    let item: WeeklyReviewItem
    let review: WeeklyReview
    let tasks: [TaskItem]
    let projectsNeedingAction: [Project]
    let openTaskCount: Int
    let isCurrentStep: Bool
    let complete: () -> Void
    let skip: () -> Void
    let returnToCurrent: () -> Void
    let decide: (WeeklyReviewStaleDecision, TaskItem) -> Void

    private var staleTasks: [TaskItem] {
        tasks.filter { review.staleTaskIDs.contains($0.id.uuidString) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Text(item.sortOrder + 1, format: .number)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.themeTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.themePrimary.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.title3.weight(.bold))
                    Text(item.instructions).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            contextContent

            if item.isComplete || item.isSkipped {
                HStack(spacing: 10) {
                    Button("Saved") { }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.themeButtonBackground)
                        .disabled(true)
                        .accessibilityIdentifier("complete-review-step-\(item.sortOrder)")
                    if !isCurrentStep && review.currentStep < (review.checklistItems?.count ?? 0) {
                        Button("Return to current step", action: returnToCurrent)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("return-to-current-review-step")
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button("Complete", action: complete)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.themeButtonBackground)
                        .accessibilityIdentifier("complete-review-step-\(item.sortOrder)")
                    Button("Skip", action: skip)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("skip-review-step-\(item.sortOrder)")
                }
            }
        }
        .padding(18)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.themeBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("weekly-review-step-\(item.sortOrder)")
    }

    @ViewBuilder
    private var contextContent: some View {
        switch item.kind {
        case .collect:
            ReviewContextSummary(symbol: "tray.and.arrow.down.fill", text: "Gather loose notes, messages, and papers before moving on.")
        case .process:
            let count = tasks.filter { $0.status == .inbox }.count
            ReviewContextSummary(symbol: "tray.fill", text: count == 0 ? "Your Inbox is clear." : "\(count) Inbox items are waiting to be clarified.")
        case .stale:
            if staleTasks.isEmpty {
                ReviewContextSummary(symbol: "checkmark.circle.fill", text: "Nothing stale")
                    .accessibilityIdentifier("review-no-stale-items")
            } else {
                VStack(spacing: 0) {
                    ForEach(staleTasks) { task in
                        HStack(spacing: 10) {
                            Text(task.title).font(.subheadline).lineLimit(2)
                            Spacer()
                            Menu("Decide") {
                                Button("Promote to Next Action") { decide(.promote, task) }
                                Button("Keep") { decide(.keep, task) }
                                Button("Delete", role: .destructive) { decide(.delete, task) }
                            }
                            .accessibilityIdentifier("stale-decision-\(task.id.uuidString)")
                        }
                        .padding(.vertical, 10)
                        if task.id != staleTasks.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.themeBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .organize:
            WeeklyReviewProjectStatusView(flaggedCount: projectsNeedingAction.count)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themeBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .review:
            let count = tasks.filter { $0.status == .waitingFor }.count
            ReviewContextSummary(symbol: "hourglass", text: count == 0 ? "Nothing is waiting on someone else." : "\(count) waiting items may need a follow-up.")
        case .plan:
            ReviewContextSummary(symbol: "calendar", text: "\(openTaskCount) open commitments remain. Choose the few that deserve attention next.")
        }
    }
}

private struct ReviewContextSummary: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.themeBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ReviewCompletionView: View {
    let review: WeeklyReview
    let openTaskCount: Int
    let startNewReview: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: review.status == .completed ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(review.status == .completed ? Color.themeTextPrimary : .orange)
            VStack(spacing: 6) {
                Text(review.status == .completed ? "Review complete" : "Partial review")
                    .font(.title2.weight(.bold))
                Text(review.status == .completed ? "Your week is clear." : "You made progress and left a few loops open.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                ReviewMetric(value: review.completedStepCount, label: "Completed", symbol: "checkmark")
                Divider().frame(height: 38)
                ReviewMetric(value: review.skippedStepCount, label: "Skipped", symbol: "arrow.right")
                Divider().frame(height: 38)
                ReviewMetric(value: openTaskCount, label: "Still open", symbol: "circle")
            }
            Button(action: startNewReview) {
                Text("Start a new review")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.themeButtonForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.themeButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("start-new-weekly-review")
        }
        .padding(20)
        .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review-completion-summary")
    }
}

private struct ReviewAreasLink: View {
    let areaCount: Int

    var body: some View {
        NavigationLink { AreasView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.2x2.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 38, height: 38)
                    .background(Color.orange.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Areas of focus").font(.subheadline.weight(.semibold))
                    Text("Review the responsibilities you keep healthy")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(areaCount, format: .number).font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.themeCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review-areas-overview")
    }
}

private struct WorkspaceTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FeatureFlags.self) private var featureFlags

    let task: TaskItem
    @State private var title: String
    @State private var notes: String
    @State private var status: Status
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _status = State(initialValue: task.status)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? .now)
    }

    var body: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                    .accessibilityIdentifier("task-detail-title")
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("task-detail-notes")
            }

            Section("task organization") {
                Picker("Status", selection: $status) {
                    ForEach(Status.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .accessibilityIdentifier("task-detail-status")
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
        .navigationTitle("Task details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanTitle.isEmpty else { return }
                    task.title = cleanTitle
                    task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    task.status = status
                    task.dueDate = hasDueDate ? dueDate : nil
                    task.updatedAt = .now
                    try? modelContext.save()
                    TaskDueNotificationService.shared.sync(task: task)
                    dismiss()
                }
                .accessibilityIdentifier("task-detail-save")
            }
        }
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32, weight: .medium)).foregroundStyle(Color.themeTextPrimary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct CaptureSheet: View {
    private enum Phase: Equatable {
        case capture
        case confirmation
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FeatureFlags.self) private var featureFlags
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Area.name) private var areas: [Area]
    let defaultStatus: Status
    @State private var selectedStatus: Status
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var tags = ""
    @State private var selectedProjectID: UUID?
    @State private var selectedAreaID: UUID?
    @State private var isSaving = false
    @State private var phase: Phase = .capture
    @State private var persistedItem: TaskItem?
    @State private var didConfirm = false
    @State private var saveErrorMessage: String?
    @State private var voiceCapture = VoiceCaptureService()
    @State private var voiceLanguage: VoiceCaptureLanguage = .english

    init(defaultStatus: Status) {
        self.defaultStatus = defaultStatus
        _selectedStatus = State(initialValue: defaultStatus)
        let processInfo = ProcessInfo.processInfo
        let testTitle = processInfo.arguments.contains("-ui-testing")
            ? (processInfo.environment["WOOL_UI_TEST_CAPTURE_TITLE"] ?? "")
            : ""
        _title = State(initialValue: testTitle)
    }

    var body: some View {
        NavigationStack {
            Group {
                if phase == .capture {
                    captureForm
                } else {
                    confirmationForm
                }
            }
            .navigationTitle(phase == .capture ? "New capture" : "Confirm capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if phase == .confirmation {
                            leaveAsInbox()
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await saveCapture() } } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(phase == .capture ? "Save" : "Confirm")
                        }
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSaving
                            || (phase == .confirmation && persistedItem == nil)
                    )
                }
            }
            .onDisappear {
                voiceCapture.cancel()
                // A swipe-back or dismissal from the recommendation screen is
                // still a successful capture, but must leave it raw in Inbox.
                if phase == .confirmation, !didConfirm {
                    resetPersistedItemToInbox()
                }
            }
            .alert("Capture not saved", isPresented: saveErrorPresented) {
                Button("Retry") { Task { await saveCapture() } }
                Button("Keep text", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "Your capture is still on screen. Try saving again when storage is available.")
            }
            .onChange(of: voiceCapture.transcript) { _, newValue in
                guard voiceCapture.isRecording || voiceCapture.state == .completed else { return }
                title = newValue
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                voiceCapture.handleInterruption()
            }
        }
    }

    private var captureForm: some View {
        Form {
            Section("Capture") {
                HStack(alignment: .top, spacing: 10) {
                    TextField("What’s on your mind?", text: $title, axis: .vertical)
                        .lineLimit(1...8)
                        .accessibilityIdentifier("capture-title-field")

                    Button {
                        if voiceCapture.isRecording {
                            voiceCapture.stop()
                        } else {
                            Task { await voiceCapture.start(language: voiceLanguage) }
                        }
                    } label: {
                        Image(systemName: voiceCapture.isRecording ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .frame(width: 38, height: 38)
                            .foregroundStyle(voiceCapture.isRecording ? .red : Color.themePrimary)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")
                    .accessibilityIdentifier(voiceCapture.isRecording ? "capture-voice-stop" : "capture-voice-mic")
                }

                if featureFlags.malayalamVoiceEnabled {
                    Picker("Voice language", selection: $voiceLanguage) {
                        ForEach(VoiceCaptureLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .accessibilityIdentifier("capture-voice-language")
                }

                if voiceCapture.isRecording {
                    Label("Listening… tap stop when you’re done", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("capture-live-status")
                }

                if let failure = voiceCapture.failure {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(failure.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("capture-voice-error")

                        HStack {
                            Button("Retry") {
                                Task { await voiceCapture.start(language: voiceLanguage) }
                            }
                            .accessibilityIdentifier("capture-voice-retry")

                            Button("Type instead") {
                                voiceCapture.reset()
                            }
                            .accessibilityIdentifier("capture-voice-type-instead")

                            if failure == .bridgeOffline && voiceLanguage == .malayalam {
                                Button("Try English") {
                                    voiceLanguage = .english
                                    Task { await voiceCapture.start(language: .english) }
                                }
                                .accessibilityIdentifier("capture-voice-try-english")
                            }

                            if failure == .microphonePermissionDenied || failure == .speechPermissionDenied {
                                Button("Open Settings") { openSettings() }
                                    .accessibilityIdentifier("capture-voice-open-settings")
                            }
                        }
                    }
                }
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("capture-notes-field")
            }
            Section {
                Text("It will be sorted with a quick confirmation before it leaves Inbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var confirmationForm: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                    .accessibilityIdentifier("capture-confirmation-title")
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Label("Review suggestion", systemImage: "sparkles")
            } footer: {
                Text("Nothing is filed until you confirm. You can change any field.")
            }

            Section("Category") {
                ForEach([Status.inbox, .nextAction, .waitingFor, .somedayMaybe], id: \.self) { status in
                    Button {
                        selectedStatus = status
                    } label: {
                        HStack {
                            Image(systemName: selectedStatus == status ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedStatus == status ? Color.themePrimary : .secondary)
                            Text(status.displayName)
                            Spacer()
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("capture-category-\(status.rawValue)")
                }
            }

            Section("Area") {
                Button {
                    selectedAreaID = nil
                } label: {
                    triageChoice(title: "No area", isSelected: selectedAreaID == nil)
                }
                .foregroundStyle(.primary)
                ForEach(areas) { area in
                    Button {
                        selectedAreaID = area.id
                    } label: {
                        triageChoice(title: area.name, isSelected: selectedAreaID == area.id)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("capture-area-\(area.id.uuidString)")
                }
            }

            Section("Project") {
                Picker("Project", selection: $selectedProjectID) {
                    Text("No project").tag(UUID?.none)
                    ForEach(projects) { project in Text(project.title).tag(Optional(project.id)) }
                }
            }

            Section("Due date") {
                Toggle("Add due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("Tags") {
                TextField("Context tags (comma separated)", text: $tags)
            }
        }
    }

    private func saveCapture() async {
        isSaving = true
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { isSaving = false; return }

        if phase == .capture {
            let captureText = notes.isEmpty ? cleanTitle : "\(cleanTitle)\n\(notes)"
            // Persist the exact raw capture first. Recommendations are kept in
            // view state until the user confirms them.
            let item = TaskItem(title: cleanTitle, notes: notes, status: .inbox)
            do {
                try CapturePersistenceService.save(item, in: modelContext)
                persistedItem = item

                // processCapture always returns a result, using heuristics when
                // Apple Intelligence is unavailable or fails.
                let recommendation = await CaptureService.shared.processCapture(text: captureText)
                selectedStatus = recommendation.status
                selectedAreaID = areas.first { area in
                    recommendation.contextTags.contains { tag in
                        tag.replacingOccurrences(of: "area:", with: "")
                            .localizedCaseInsensitiveCompare(area.name) == .orderedSame
                    }
                }?.id
                selectedProjectID = InboxBehavior.suggestedProject(in: projects, matching: captureText)?.id
                hasDueDate = recommendation.dueDate != nil
                dueDate = recommendation.dueDate ?? .now
                tags = recommendation.contextTags.map { $0.replacingOccurrences(of: "area:", with: "") }.joined(separator: ", ")
                phase = .confirmation
            } catch {
                // The raw item is already safely in Inbox if classification or
                // the UI transition cannot complete.
            }
        } else {
            applyConfirmationToPersistedItem()
            do {
                try modelContext.save()
                didConfirm = true
                dismiss()
            } catch {
                saveErrorMessage = "Your capture is still on screen. Try saving again when storage is available."
            }
        }
        isSaving = false
    }

    private func openSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func applyConfirmationToPersistedItem() {
        guard let item = persistedItem else { return }
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = notes
        item.status = selectedStatus
        item.project = projects.first { $0.id == selectedProjectID }
        item.areas = areas.first { $0.id == selectedAreaID }.map { [$0] } ?? []
        let manualTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        item.contextTags = manualTags.isEmpty ? [] : Array(Set(manualTags)).sorted()
        item.dueDate = hasDueDate ? dueDate : nil
        TaskDueNotificationService.shared.sync(task: item)
    }

    private func leaveAsInbox() {
        resetPersistedItemToInbox()
        dismiss()
    }

    private func resetPersistedItemToInbox() {
        guard let item = persistedItem else { return }
        item.status = .inbox
        item.contextTags = []
        item.project = nil
        item.areas = []
        item.dueDate = nil
        try? modelContext.save()
        TaskDueNotificationService.shared.cancel(taskID: item.id)
    }

    private func triageChoice(title: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.themePrimary : .secondary)
            Text(title)
            Spacer()
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

}

private struct NewAreaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Area.name) private var areas: [Area]
    @State private var name = ""
    @State private var notes = ""
    @State private var validationError: AreaNameValidationError?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Area name", text: $name)
                    .accessibilityIdentifier("new-area-name")
                TextField("What does this area represent?", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            .navigationTitle("New area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard AreaNaming.validate(name, against: areas) == nil else {
                            validationError = AreaNaming.validate(name, against: areas)
                            return
                        }
                        modelContext.insert(Area(name: name.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Area not created", isPresented: Binding(get: { validationError != nil }, set: { if !$0 { validationError = nil } })) {
                Button("OK", role: .cancel) { validationError = nil }
            } message: {
                Text(validationError?.errorDescription ?? "Please check the Area name.")
            }
        }
    }
}

private struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var outcome = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Project name", text: $title)
                TextField("Desired outcome", text: $outcome, axis: .vertical).lineLimit(2...4)
            }
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        modelContext.insert(Project(title: title, desiredOutcome: outcome))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
#endif
