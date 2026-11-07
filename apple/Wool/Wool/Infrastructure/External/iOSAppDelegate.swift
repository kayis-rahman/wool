import SwiftUI
import UserNotifications

#if os(iOS)
import UIKit

final class IOSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleSignificantTimeChange), name: UIApplication.significantTimeChangeNotification, object: nil)
        requestNotificationPermissions()
        return true
    }

    private func requestNotificationPermissions() {
        AppLogger.info("Requesting notification permissions on iOS", category: .general)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            AppLogger.info("iOS notification permission granted: \(granted)", category: .general)
            if granted {
                DispatchQueue.main.async { self.rescheduleNotifications() }
            }
        }
    }

    private func rescheduleNotifications() {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: "notificationsEnabled") == nil || defaults.bool(forKey: "notificationsEnabled")
        if notificationsEnabled {
            DailyBriefingReminderService.shared.schedule()
            let weeklyReviewReminderEnabled = defaults.object(forKey: "weeklyReviewReminderEnabled") == nil || defaults.bool(forKey: "weeklyReviewReminderEnabled")
            if weeklyReviewReminderEnabled {
                WeeklyReviewReminderService.shared.schedule()
            } else {
                WeeklyReviewReminderService.shared.cancel()
            }
        } else {
            DailyBriefingReminderService.shared.cancel()
            WeeklyReviewReminderService.shared.cancel()
            NotificationManager.shared.cancelSessionDoneNotification()
        }
    }

    @objc
    func handleSignificantTimeChange() {
        rescheduleNotifications()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            UIApplication.shared.open(url)
        }
        completionHandler()
    }

    @MainActor
    func applicationDidEnterBackground(_ application: UIApplication) {
        TimerSyncManager.shared.getTimer()?.persistState()
    }

    @MainActor
    func applicationWillEnterForeground(_ application: UIApplication) {
        TimerSyncManager.shared.getTimer()?.reconcile()
    }
}
#endif
