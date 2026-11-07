import Foundation
import CloudKit

final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let notificationCenter = NotificationCenter.default

    private init() {
        // Listen for iCloud changes
        notificationCenter.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc private func storeDidChange() {
        // Handle incoming iCloud changes
        DispatchQueue.main.async {
            // Notify that settings have changed from iCloud
            NotificationCenter.default.post(name: .iCloudSettingsDidChange, object: nil)
        }
    }

    // MARK: - Timer Settings Sync

    func syncTimerSettings(_ settings: TimerSettings) {
        store.set(settings.workDuration, forKey: "workDuration")
        store.set(settings.breakDuration, forKey: "breakDuration")
        store.set(settings.longBreakDuration, forKey: "longBreakDuration")
        store.set(settings.autoStartNextSession, forKey: "autoStartNextSession")
        store.synchronize()

        AppLogger.info("Timer settings synced to iCloud", category: .sync)
    }

    func loadTimerSettings() -> TimerSettings? {
        guard store.bool(forKey: "hasSyncedSettings") else { return nil }

        let workDuration = store.longLong(forKey: "workDuration")
        let breakDuration = store.longLong(forKey: "breakDuration")
        let longBreakDuration = store.longLong(forKey: "longBreakDuration")
        let autoStartNextSession = store.bool(forKey: "autoStartNextSession")

        guard workDuration > 0, breakDuration > 0, longBreakDuration > 0 else { return nil }

        return TimerSettings(
            workDuration: Int(workDuration),
            breakDuration: Int(breakDuration),
            longBreakDuration: Int(longBreakDuration),
            autoStartNextSession: autoStartNextSession
        )
    }

    func markSettingsAsSynced() {
        store.set(true, forKey: "hasSyncedSettings")
        store.synchronize()
    }
}

// MARK: - Timer Settings Model

struct TimerSettings {
    let workDuration: Int
    let breakDuration: Int
    let longBreakDuration: Int
    let autoStartNextSession: Bool
}

// MARK: - Notifications

extension Notification.Name {
    static let iCloudSettingsDidChange = Notification.Name("iCloudSettingsDidChange")
}