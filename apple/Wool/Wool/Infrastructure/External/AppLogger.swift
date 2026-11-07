import Foundation
import os.log

/// Centralized logging utility using Apple's Unified Logging System
/// Provides clean API, proper categorization, and automatic privacy controls

//
//  AppLogger.swift
//  Wool
//
//  Apple's Unified Logging System wrapper for Wool
//  Provides centralized, performant, privacy-compliant logging
//
//  Created following Bugfender Swift Logging Guide best practices
//

final class AppLogger {
    /// Log categories for better organization and filtering
    enum Category: String {
        case auth        // Authentication events, login/logout, token operations
        case sync        // Timer synchronization, backend communication, state merging
        case timer       // Pomodoro timer events, phase changes, session tracking
        case api         // HTTP requests, responses, network operations
        case lifecycle   // App lifecycle, view appearances, background tasks
        case ui          // User interactions, button taps, navigation
        case general     // Everything else
    }

    /// Subsystem identifier for Wool
    private static let subsystem = "com.sparkage.wool"

    /// Get logger instance for specific category
    private static func logger(for category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: - Static Logging Methods

    /// Debug level logging - only active in DEBUG builds for development
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category for organization
    static func debug(_ message: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).debug("\(message, privacy: .public)")
        FileLogger.writeToFile(level: "DEBUG", category: category.rawValue, message: message)
        #endif
    }

    /// Info level logging - general operational information
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category for organization
    static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(message, privacy: .public)")
        #if DEBUG
        FileLogger.writeToFile(level: "INFO", category: category.rawValue, message: message)
        #endif
    }

    /// Warning level logging - potential issues requiring attention
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category for organization
    static func warning(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
        #if DEBUG
        FileLogger.writeToFile(level: "WARNING", category: category.rawValue, message: message)
        #endif
    }

    /// Error level logging - actual errors requiring immediate action
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category for organization
    static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("\(message, privacy: .public)")
        #if DEBUG
        FileLogger.writeToFile(level: "ERROR", category: category.rawValue, message: message)
        #endif
    }

    /// Fault level logging - critical errors that may crash the system
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category for organization
    static func fault(_ message: String, category: Category = .general) {
        logger(for: category).fault("\(message, privacy: .public)")
        #if DEBUG
        FileLogger.writeToFile(level: "FAULT", category: category.rawValue, message: message)
        #endif
    }

    // MARK: - Privacy-Aware Logging

    /// Info logging with private data protection
    /// - Parameters:
    ///   - message: Public log message
    ///   - privateData: Sensitive data that's automatically redacted in logs
    ///   - category: Log category for organization
    static func infoWithPrivate(_ message: String, privateData: String, category: Category = .general) {
        logger(for: category).info("\(message, privacy: .public) - \(privateData, privacy: .private)")
    }

    /// Debug logging with private data protection (DEBUG builds only)
    /// - Parameters:
    ///   - message: Public log message
    ///   - privateData: Sensitive data that's automatically redacted in logs
    ///   - category: Log category for organization
    static func debugWithPrivate(_ message: String, privateData: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).debug("\(message, privacy: .public) - \(privateData, privacy: .private)")
        #endif
    }

    // MARK: - Structured Logging Helpers

    /// Log authentication events
    static func logAuthEvent(_ event: String, userId: String? = nil) {
        if let userId = userId {
            infoWithPrivate("Auth event: \(event)", privateData: "userId: \(userId)", category: .auth)
        } else {
            info("Auth event: \(event)", category: .auth)
        }
    }

    /// Log timer synchronization events
    static func logSyncEvent(_ event: String, details: String? = nil) {
        if let details = details {
            info("Sync event: \(event) - \(details)", category: .sync)
        } else {
            info("Sync event: \(event)", category: .sync)
        }
    }

    /// Log timer phase changes
    static func logTimerEvent(_ event: String, phase: String? = nil) {
        if let phase = phase {
            info("Timer event: \(event) - phase: \(phase)", category: .timer)
        } else {
            info("Timer event: \(event)", category: .timer)
        }
    }

    /// Log API requests/responses
    static func logAPIEvent(_ event: String, url: String? = nil) {
        if let url = url {
            info("API event: \(event) - URL: \(url)", category: .api)
        } else {
            info("API event: \(event)", category: .api)
        }
    }

    /// Log app lifecycle events
    static func logLifecycleEvent(_ event: String) {
        info("Lifecycle event: \(event)", category: .lifecycle)
    }

    /// Log UI interaction events
    static func logUIEvent(_ event: String, details: String? = nil) {
        if let details = details {
            info("UI event: \(event) - \(details)", category: .ui)
        } else {
            info("UI event: \(event)", category: .ui)
        }
    }

    // MARK: - File Logging Setup

    /// Initialize file logging system (call this on app startup)
    /// Should be called from AppDelegate or SwiftUI App's init
    static func initializeFileLogging() {
        #if DEBUG
        FileLogger.initialize()
        FileLogger.cleanupOldLogs()
        #endif
    }

    /// Get the file logger URL for debugging purposes
    static func getLogFileURL() -> Foundation.URL {
        return FileLogger.getLogFileURL()
    }
}
