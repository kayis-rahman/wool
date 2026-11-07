import UserNotifications

protocol LocalNotificationCenter {
    func add(_ request: UNNotificationRequest)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: LocalNotificationCenter {
    func add(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}
