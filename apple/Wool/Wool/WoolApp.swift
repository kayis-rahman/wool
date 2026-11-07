import SwiftUI
import Observation
import SwiftData
import UserNotifications

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

// MARK: - Main App Structure

@main
struct WoolApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) var appDelegate
    #endif

    @State var timer = PomodoroTimer()
    @State var logger = SessionLogger()
    @State var authManager = AuthManager.shared
    @State var featureFlags = FeatureFlags.shared

    @State private var isAppReady = false

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            Group {
                if isAppReady {
                    WorkspaceView()
                    .preferredColorScheme(AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue)?.colorScheme)
                    .environment(timer)
                    .environment(logger)
                    .environment(authManager)
                    .environment(featureFlags)
                } else {
                    LoadingView()
                        .onAppear {
                            Task {
                                await setupApp()
                            }
                        }
                }
            }
            #else
            Group {
                if isAppReady {
                    macOSContentView()
                    .environment(timer)
                    .environment(logger)
                    .environment(authManager)
                    .environment(featureFlags)
                } else {
                    LoadingView()
                        .onAppear {
                            Task {
                                await setupApp()
                            }
                        }
                }
            }
            #endif
        }
        .modelContainer(WoolModelContainer.shared)
    }

    @MainActor
    private func setupApp() async {
        let processInfo = ProcessInfo.processInfo
        timer.onFocusSessionCompleted = { record in
            logger.add(record: record)
        }
        if processInfo.arguments.contains("-focus-test-reset") {
            FocusTimerPersistence.clear()
            timer.reset()
        } else {
            timer.restorePersistedState()
        }
        if processInfo.arguments.contains("-ui-testing") ||
            processInfo.environment["WOOL_UI_TESTING"] == "1" {
            try? WorkspaceUITestData.seedProjectsAndAreasIfRequested(
                in: ModelContext(WoolModelContainer.shared)
            )
            try? WorkspaceUITestData.seedWeeklyReviewStaleItemIfRequested(
                in: ModelContext(WoolModelContainer.shared)
            )
            try? WorkspaceUITestData.seedDailyBriefingIfRequested(
                in: ModelContext(WoolModelContainer.shared)
            )
            try? WorkspaceUITestData.seedGmailIfRequested(
                in: ModelContext(WoolModelContainer.shared)
            )
            isAppReady = true
            Self.scheduleWeeklyReviewReminderIfEnabled()
            Self.scheduleDailyBriefingReminderIfEnabled()
            return
        }

        // Restore auth session
        await authManager.restoreSession()

        // Timer state is restored from local persistence above. There is no
        // remote timer backend to pull from.
        TimerSyncManager.shared.configure(with: timer)

        // Cache remote rollout changes for the next launch. The active flag
        // snapshot remains stable for the duration of this session.
        await featureFlags.refreshRemoteConfiguration()

        isAppReady = true
        UserDefaults.standard.set(true, forKey: WoolModelContainer.appSetupCompletedKey)
        Self.scheduleWeeklyReviewReminderIfEnabled()
        Self.scheduleDailyBriefingReminderIfEnabled()
    }

    /// Schedules the weekly review reminder only when the user has not opted
    /// out via the Notifications section in Settings. Both preferences
    /// default to `true` when unset.
    private static func scheduleWeeklyReviewReminderIfEnabled() {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: "notificationsEnabled") == nil || defaults.bool(forKey: "notificationsEnabled")
        let weeklyReviewReminderEnabled = defaults.object(forKey: "weeklyReviewReminderEnabled") == nil || defaults.bool(forKey: "weeklyReviewReminderEnabled")
        if notificationsEnabled && weeklyReviewReminderEnabled {
            WeeklyReviewReminderService.shared.schedule()
        } else {
            WeeklyReviewReminderService.shared.cancel()
        }
    }

    /// Schedules the daily briefing reminder while notifications are enabled.
    /// Daily briefing does not have a dedicated toggle yet; the master
    /// notifications preference governs it.
    private static func scheduleDailyBriefingReminderIfEnabled() {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: "notificationsEnabled") == nil || defaults.bool(forKey: "notificationsEnabled")
        if notificationsEnabled {
            DailyBriefingReminderService.shared.schedule()
        } else {
            DailyBriefingReminderService.shared.cancel()
        }
    }
}
