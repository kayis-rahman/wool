import os

enum LoggerStore {
    static let timer = Logger(subsystem: "com.sparkage.wool", category: "Timer")
    static let session = Logger(subsystem: "com.sparkage.wool", category: "SessionAPI")
    static let auth = Logger(subsystem: "com.sparkage.wool", category: "Auth")
    static let general = Logger(subsystem: "com.sparkage.wool", category: "General")
}
