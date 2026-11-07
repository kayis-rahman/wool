import Foundation
import UserNotifications

#if os(iOS)
import UIKit
#endif

#if os(watchOS)
import WatchKit
#endif

open class NotificationManager {
    public static let focusCompletionIdentifier = "wool.focus-session-completion"
    // Allow tests to replace the shared instance
    public static var shared: NotificationManager = NotificationManager()
    public init() {}

    // Helper for tests to restore default shared instance
    public static func resetShared() { shared = NotificationManager() }

    open func requestPermission(completion: ((Bool) -> Void)? = nil) {
        #if os(iOS) || os(macOS)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion?(granted)
        }
        #else
        completion?(true)
        #endif
    }

    open func sendSessionDoneNotification(phase: String) {
        #if os(iOS) || os(macOS)
        let content = UNMutableNotificationContent()
        content.title = "Wool"
        if phase == "work" {
            content.body = "Work session done! Time for a break."
        } else {
            content.body = "Break session done! Time to focus."
        }
        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            if Bundle.main.url(forResource: "chime-sound", withExtension: "mp3") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("chime-sound.mp3"))
            } else {
                content.sound = .default
            }
        } else {
            content.sound = .none
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
        triggerHapticIfNeeded()
    }

    open func scheduleSessionDoneNotification(phase: String, taskTitle: String?, at date: Date) {
        #if os(iOS) || os(macOS)
        let content = UNMutableNotificationContent()
        content.title = "Wool"
        let subject = taskTitle ?? "Focus Session"
        content.body = phase == "work"
            ? "\(subject) is complete. Time for a break."
            : "Break complete. Time to focus."
        content.sound = UserDefaults.standard.bool(forKey: "soundEnabled") ? .default : .none
        let interval = max(1, date.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: Self.focusCompletionIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.focusCompletionIdentifier])
        center.add(request, withCompletionHandler: nil)
        #endif
    }

    open func cancelSessionDoneNotification() {
        #if os(iOS) || os(macOS)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.focusCompletionIdentifier]
        )
        #endif
    }

    func triggerHapticIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "hapticsEnabled") else { return }
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
