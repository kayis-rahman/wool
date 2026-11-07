import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(SessionLogger.self) private var logger // swiftlint:disable:this sensitive_logging
    @Environment(AuthManager.self) private var authManager
    @Environment(FeatureFlags.self) private var featureFlags
    @AppStorage("appTheme") private var appTheme = AppTheme.system

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AccountSyncSettingsView() } label: {
                        SettingsAccountRow(authManager: authManager)
                    }
                    .accessibilityIdentifier("settings-account")
                }
                Section("Personalize") {
                    SettingsLink("Focus", "\(timer.workDuration / 60) min focus · \(timer.breakDuration / 60) min break", "timer", "settings-focus") { FocusSettingsView() }
                    SettingsLink("Sound & Haptics", "Feedback preferences", "speaker.wave.2.fill", "settings-sound-haptics") { SoundHapticsSettingsView() }
                    SettingsLink("Notifications", "Reminders and alerts", "bell.badge.fill", "settings-notifications") { NotificationsSettingsView() }
                    SettingsLink("Appearance", appTheme.rawValue, "circle.lefthalf.filled", "settings-appearance") { AppearanceSettingsView() }
                }
                Section("More") {
                    if featureFlags.gmailIntegrationEnabled {
                        SettingsLink("Integrations", "Gmail", "square.grid.2x2.fill", "settings-integrations") { IntegrationsSettingsView() }
                    }
                    SettingsLink("Support & About", "Help, privacy, and version", "questionmark.circle.fill", "settings-support-about") { SupportAboutSettingsView(featureFlags: featureFlags) }
                }
                Section {
                    SettingsLink("Data & Privacy", "Manage local data", "lock.shield.fill", "settings-data-privacy", tint: .orange) { DataPrivacySettingsView(timer: timer, logger: logger) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct SettingsAccountRow: View {
    let authManager: AuthManager
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: authManager.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.title2).foregroundStyle(authManager.isSignedIn ? Color.themeAccent : .secondary)
                .frame(width: 38, height: 38).background(Color.themePrimary.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.isSignedIn ? (authManager.displayName ?? "Wool user") : "Sign in with Apple").font(.headline)
                Text(authManager.isSignedIn ? (authManager.email ?? "Apple account connected") : "Sync your data across devices")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(.vertical, 5)
    }
}

private struct SettingsLink<Destination: View>: View {
    let title: String; let subtitle: String; let icon: String; let identifier: String; let tint: Color
    @ViewBuilder let destination: () -> Destination
    init(_ title: String, _ subtitle: String, _ icon: String, _ identifier: String, tint: Color = .themePrimary, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title; self.subtitle = subtitle; self.icon = icon; self.identifier = identifier; self.tint = tint; self.destination = destination
    }
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                    .frame(width: 30, height: 30).background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) { Text(title); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }.padding(.vertical, 4)
        }.accessibilityIdentifier(identifier)
    }
}

struct FocusSettingsView: View {
    @Environment(PomodoroTimer.self) private var timer
    var body: some View {
        List {
            Section { durationRow("Focus duration", timer.workDuration / 60, 15...60, 5) { timer.updateDurations(workMinutes: $0, shortBreakMinutes: timer.breakDuration / 60, longBreakMinutes: timer.longBreakDuration / 60); sync() }
                durationRow("Short break", timer.breakDuration / 60, 3...15, 1) { timer.updateDurations(workMinutes: timer.workDuration / 60, shortBreakMinutes: $0, longBreakMinutes: timer.longBreakDuration / 60); sync() }
                durationRow("Long break", timer.longBreakDuration / 60, 10...30, 5) { timer.updateDurations(workMinutes: timer.workDuration / 60, shortBreakMinutes: timer.breakDuration / 60, longBreakMinutes: $0); sync() }
            } header: { Text("Timer") } footer: { Text(timer.isRunning ? "Pause the active session before changing durations." : "Changes apply to the next session.") }
            Section { Toggle("Auto-start next session", isOn: Binding(get: { timer.autoStartNextSession }, set: { timer.autoStartNextSession = $0; sync() })).accessibilityIdentifier("settings-auto-start") }
        }.navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private func durationRow(_ title: String, _ value: Int, _ range: ClosedRange<Int>, _ step: Int, onChange: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: onChange), in: range, step: step) { VStack(alignment: .leading) { Text(title); Text("\(value) minutes").font(.caption).foregroundStyle(.secondary) } }
            .disabled(timer.isRunning).accessibilityIdentifier("settings-\(title.replacingOccurrences(of: " ", with: "-").lowercased())")
    }
    private func sync() { iCloudSyncManager.shared.syncTimerSettings(TimerSettings(workDuration: timer.workDuration, breakDuration: timer.breakDuration, longBreakDuration: timer.longBreakDuration, autoStartNextSession: timer.autoStartNextSession)) }
}

struct SoundHapticsSettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true; @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    var body: some View { List { Section { Toggle("Sound", isOn: $soundEnabled); Toggle("Haptics", isOn: $hapticsEnabled) } footer: { Text("Control feedback when sessions complete and actions are confirmed.") } }.navigationTitle("Sound & Haptics").navigationBarTitleDisplayMode(.inline) }
}

struct NotificationsSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("weeklyReviewReminderEnabled") private var weeklyReviewReminderEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newValue in
                        notificationsEnabled = newValue
                        if newValue {
                            NotificationManager.shared.requestPermission()
                            DailyBriefingReminderService.shared.schedule()
                            if weeklyReviewReminderEnabled { WeeklyReviewReminderService.shared.schedule() }
                        } else {
                            DailyBriefingReminderService.shared.cancel()
                            WeeklyReviewReminderService.shared.cancel()
                            NotificationManager.shared.cancelSessionDoneNotification()
                        }
                    }
                )).accessibilityIdentifier("settings-notifications-enabled")
            } footer: { Text("Turn off to stop all Wool reminders and alerts.") }
            Section {
                Toggle("Weekly Review Reminder", isOn: Binding(
                    get: { weeklyReviewReminderEnabled },
                    set: { newValue in
                        weeklyReviewReminderEnabled = newValue
                        if newValue {
                            WeeklyReviewReminderService.shared.schedule()
                        } else {
                            WeeklyReviewReminderService.shared.cancel()
                        }
                    }
                ))
                .disabled(!notificationsEnabled)
                .accessibilityIdentifier("settings-weekly-review-reminder")
            } footer: { Text("A weekly reminder on Monday mornings to close open loops.") }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    var body: some View { List { Section { Picker("Theme", selection: $appTheme) { ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("settings-theme-picker") } footer: { Text("System follows the appearance selected in iPhone Settings.") } }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline) }
}

struct IntegrationsSettingsView: View {
    var body: some View { List { Section { GmailIntegrationView() } header: { Text("Connected services") } footer: { Text("Imported messages become actionable items in your Inbox.") } }.navigationTitle("Integrations").navigationBarTitleDisplayMode(.inline) }
}

struct AccountSyncSettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var signInError: String?; @State private var confirmSignOut = false
    var body: some View {
        List {
            Section("Account") {
                if authManager.isSignedIn { Label { VStack(alignment: .leading) { Text(authManager.displayName ?? "Wool user").font(.headline); Text(authManager.email ?? "Apple account connected").font(.subheadline).foregroundStyle(.secondary) } } icon: { Image(systemName: "person.crop.circle.fill").foregroundStyle(Color.themeAccent) } } else { Text("Sign in with Apple to associate this installation with your Wool account.").foregroundStyle(.secondary); Button("Sign in with Apple") { signIn() }.buttonStyle(.borderedProminent).tint(Color.themeButtonBackground).accessibilityIdentifier("settings-sign-in") }
            }
            if authManager.isSignedIn {
                Section { Button("Sign out", role: .destructive) { confirmSignOut = true }.accessibilityIdentifier("settings-sign-out") }
            }
        }.navigationTitle("Account").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Sign out of Wool?", isPresented: $confirmSignOut) { Button("Sign out", role: .destructive) { Task { await authManager.signOut() } }; Button("Cancel", role: .cancel) {} } message: { Text("Your local data stays on this device.") }
            .alert("Sign-in failed", isPresented: Binding(get: { signInError != nil }, set: { if !$0 { signInError = nil } })) { Button("OK", role: .cancel) { signInError = nil } } message: { Text(signInError ?? "Please try again.") }
    }
    private func signIn() { Task { do { try await authManager.signInWithApple() } catch { signInError = error.localizedDescription } } }
}

struct SupportAboutSettingsView: View {
    let featureFlags: FeatureFlags
    var body: some View {
        List {
            Section("Support") {
                Link("Help & Support", destination: URL(string: "https://github.com/kayis-rahman/synapse/blob/develop/docs/support.md")!)
                Link("Privacy Policy", destination: URL(string: "https://github.com/kayis-rahman/synapse/blob/develop/docs/privacy.md")!)
            }
            Section("About") { LabeledContent("Version", value: Bundle.main.displayVersion) }
#if DEBUG
            if featureFlags.diagnosticsEnabled {
                Section("Developer") { NavigationLink("Feature Flags") { FeatureFlagsDebugView() } }
            }
#endif
        }
        .navigationTitle("Support & About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataPrivacySettingsView: View {
    let timer: PomodoroTimer; let logger: SessionLogger
    @State private var confirmReset = false
    @State private var confirmClearHistory = false
    @State private var exportJSONPresented = false
    @State private var exportCSVPresented = false
    @State private var importPresented = false
    @State private var jsonDocument: JSONBackupDocument?
    @State private var csvDocument: CSVBackupDocument?
    @State private var alertMessage: String?
    @State private var showAlert = false
    var body: some View {
        List {
            Section {
                Button("Export as JSON") {
                    do {
                        let context = ModelContext(WoolModelContainer.shared)
                        let data = try DataExportService.exportJSON(in: context)
                        jsonDocument = JSONBackupDocument(data: data)
                        exportJSONPresented = true
                    } catch let error { present(error) }
                }.accessibilityIdentifier("export-json")
                Button("Export as CSV") {
                    do {
                        let context = ModelContext(WoolModelContainer.shared)
                        let text = try DataExportService.exportCSV(in: context)
                        csvDocument = CSVBackupDocument(text: text)
                        exportCSVPresented = true
                    } catch let error { present(error) }
                }.accessibilityIdentifier("export-csv")
                Button("Restore from JSON", role: .destructive) {
                    importPresented = true
                }.accessibilityIdentifier("restore-json")
            } header: { Text("Export & Restore") } footer: { Text("JSON contains all tasks, projects, areas, and weekly reviews and can be restored. CSV contains tasks. Restoring replaces all current data.") }
            Section {
                Button("Reset settings to defaults", role: .destructive) { confirmReset = true }.accessibilityIdentifier("settings-reset-defaults")
                Button("Clear local focus history", role: .destructive) { confirmClearHistory = true }.accessibilityIdentifier("settings-clear-history")
            } footer: { Text("These actions do not delete your account, Gmail connections, or cloud data.") }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exportJSONPresented, document: jsonDocument, contentType: .json, defaultFilename: "wool-backup.json") { result in
            if case .failure(let error) = result { present(error) }
        }
        .fileExporter(isPresented: $exportCSVPresented, document: csvDocument, contentType: .plainText, defaultFilename: "wool-tasks.csv") { result in
            if case .failure(let error) = result { present(error) }
        }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    let context = ModelContext(WoolModelContainer.shared)
                    try DataExportService.restore(from: data, in: context)
                    alertMessage = "Data restored successfully."
                    showAlert = true
                } catch let error { present(error) }
            case .failure(let error):
                present(error)
            }
        }
        .alert("Data & Privacy", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog("Reset settings?", isPresented: $confirmReset) { Button("Reset settings", role: .destructive) { timer.resetDurationsToDefaults(); UserDefaults.standard.set(true, forKey: "soundEnabled"); UserDefaults.standard.set(true, forKey: "hapticsEnabled"); UserDefaults.standard.set(AppTheme.system.rawValue, forKey: "appTheme") }; Button("Cancel", role: .cancel) {} } message: { Text("Timer durations, sound, haptics, and appearance will return to their defaults.") }
        .confirmationDialog("Clear local focus history?", isPresented: $confirmClearHistory) { Button("Clear history", role: .destructive) { logger.clear() }; Button("Cancel", role: .cancel) {} } message: { Text("This removes focus-session history stored on this device. Account and cloud data are not affected.") }
    }
    private func present(_ error: Error) {
        alertMessage = error.localizedDescription
        showAlert = true
    }
}


struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CSVBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText, .commaSeparatedText]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.text = String(data: data, encoding: .utf8) ?? ""
        } else {
            self.text = ""
        }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview { SettingsView().environment(PomodoroTimer()).environment(SessionLogger()).environment(AuthManager.shared).environment(FeatureFlags(userDefaults: UserDefaults(suiteName: "Wool.SettingsPreview") ?? .standard)) }
