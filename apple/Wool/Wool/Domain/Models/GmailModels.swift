import Foundation
import SwiftData

enum GmailAccountStatus: String, Codable, CaseIterable {
    case connected
    case syncing
    case paused
    case reauthorizationRequired
    case temporarilyUnavailable
    case disconnected
}

enum GmailSourceState: String, Codable {
    case available
    case deleted
    case inaccessible
    case archived
}

enum GmailSyncMode: String, Codable {
    case initial
    case incremental
    case recovery
}

@Model
final class GmailAccountRecord: Identifiable {
    var id: UUID = UUID()
    var accountIdentifier: String = ""
    var displayName: String = ""
    var statusRawValue: String = GmailAccountStatus.disconnected.rawValue
    var isEnabled: Bool = true
    var connectedAt: Date = Date()
    var lastSyncAttemptAt: Date?
    var lastSuccessfulSyncAt: Date?
    var lastErrorCode: String?
    var lastErrorMessage: String?

    var status: GmailAccountStatus {
        get { GmailAccountStatus(rawValue: statusRawValue) ?? .disconnected }
        set { statusRawValue = newValue.rawValue }
    }

    init(accountIdentifier: String, displayName: String = "", status: GmailAccountStatus = .connected) {
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.statusRawValue = status.rawValue
    }
}

@Model
final class GmailImportedMessageRecord {
    var id: UUID = UUID()
    var accountIdentifier: String = ""
    var gmailMessageID: String = ""
    var gmailThreadID: String = ""
    var taskID: UUID = UUID()
    var sourceURL: String = ""
    var receivedAt: Date?
    var subject: String = ""
    var sender: String = ""
    var sourceStateRawValue: String = GmailSourceState.available.rawValue
    var lastSyncedAt: Date = Date()

    var sourceState: GmailSourceState {
        get { GmailSourceState(rawValue: sourceStateRawValue) ?? .available }
        set { sourceStateRawValue = newValue.rawValue }
    }

    init(
        accountIdentifier: String,
        gmailMessageID: String,
        gmailThreadID: String = "",
        taskID: UUID,
        sourceURL: String = "",
        receivedAt: Date? = nil,
        subject: String = "",
        sender: String = ""
    ) {
        self.accountIdentifier = accountIdentifier
        self.gmailMessageID = gmailMessageID
        self.gmailThreadID = gmailThreadID
        self.taskID = taskID
        self.sourceURL = sourceURL
        self.receivedAt = receivedAt
        self.subject = subject
        self.sender = sender
    }
}

@Model
final class GmailSyncCheckpointRecord {
    var id: UUID = UUID()
    var accountIdentifier: String = ""
    var historyID: String?
    var pageToken: String?
    var syncModeRawValue: String = GmailSyncMode.initial.rawValue
    var updatedAt: Date = Date()

    var syncMode: GmailSyncMode {
        get { GmailSyncMode(rawValue: syncModeRawValue) ?? .initial }
        set { syncModeRawValue = newValue.rawValue }
    }

    init(accountIdentifier: String, mode: GmailSyncMode = .initial) {
        self.accountIdentifier = accountIdentifier
        self.syncModeRawValue = mode.rawValue
    }
}
