import Foundation
import os.log

/// File logging utility for Wool iOS/macOS apps
/// Provides persistent file logging alongside Apple's Unified Logging System
/// Replaces log file on each app launch for clean debugging sessions

final class FileLogger {
    private static let logger = os.Logger(subsystem: "com.sparkage.wool", category: "filelogger")
    
    /// Log file URL for current platform
    private static var logFileURL: URL {
        get {
            #if os(iOS)
            // iOS/macOS app documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logsPath = documentsPath.appendingPathComponent("WoolLogs")
            #elseif os(macOS)
            // macOS user documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logsPath = documentsPath.appendingPathComponent("WoolLogs")
            #else
            // Fallback for other platforms
            let documentsPath = FileManager.default.temporaryDirectory
            let logsPath = documentsPath.appendingPathComponent("WoolLogs")
            #endif
            
            // Create logs directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: logsPath.path) {
                try? FileManager.default.createDirectory(at: logsPath, withIntermediateDirectories: true)
            }
            
            // Determine platform for file naming
            let platform: String
            #if os(iOS)
            platform = "iOS"
            #elseif os(macOS)
            platform = "macOS"
            #elseif os(watchOS)
            platform = "watchOS"
            #else
            platform = "unknown"
            #endif
            
            return logsPath.appendingPathComponent("wool_\(platform.lowercased()).log")
        }
    }
    
    /// Initialize and clear log file (call this on app startup)
    static func initialize() {
        #if DEBUG
        do {
            // Create empty log file or clear existing one
            let logContent = "=== Wool App Launch - \(Date()) ===\n"
            try logContent.write(to: logFileURL, atomically: true, encoding: .utf8)
            logger.info("File logger initialized: \(logFileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to initialize file logger: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
    
    /// Write log message to file (only in DEBUG builds)
    /// - Parameters:
    ///   - level: Log level (DEBUG, INFO, WARNING, ERROR, FAULT)
    ///   - category: Log category for organization
    ///   - message: Log message
    static func writeToFile(level: String, category: String, message: String) {
        #if DEBUG
        do {
            let timestamp = DateFormatter.logFileFormatter.string(from: Date())
            let platform: String
            #if os(iOS)
            platform = "iOS"
            #elseif os(macOS)
            platform = "macOS"
            #elseif os(watchOS)
            platform = "watchOS"
            #else
            platform = "unknown"
            #endif

            // Format: [TIMESTAMP] [PLATFORM] [LEVEL] [CATEGORY] Message
            let logEntry = "[\(timestamp)] [\(platform)] [\(level)] [\(category.uppercased())] \(message)\n"

            // Ensure the log file exists; if not, create it with empty content first
            let fm = FileManager.default
            if !fm.fileExists(atPath: logFileURL.path) {
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            }

            // Append to file using a throwing FileHandle initializer
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            if let data = logEntry.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
        } catch {
            logger.error("Failed to write to file log: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
    
    /// Get log file URL for debugging purposes
    static func getLogFileURL() -> URL {
        return logFileURL
    }
    
    /// Clean up old log files (keep only most recent)
    static func cleanupOldLogs() {
        #if DEBUG
        do {
            let logsDirectory = logFileURL.deletingLastPathComponent()
            let fileManager = FileManager.default
            
            // Get all log files
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let date2 = try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
            
            // Keep only the most recent 5 files
            for (index, logFile) in logFiles.enumerated() {
                if index >= 5 {
                    try? fileManager.removeItem(at: logFile)
                    logger.info("Removed old log file: \(logFile.lastPathComponent, privacy: .public)")
                }
            }
        } catch {
            logger.error("Failed to cleanup old logs: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}

/// Date formatter for log file timestamps
extension DateFormatter {
    static let logFileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
