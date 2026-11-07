import Foundation
import SwiftData

struct GmailProfile: Equatable, Sendable {
    let email: String
    let displayName: String
}

struct GmailMessage: Equatable, Sendable {
    let id: String
    let threadID: String
    let subject: String
    let sender: String
    let body: String
    let receivedAt: Date?
    let webURL: String
    let hasAttachments: Bool
}

struct GmailMessagePage: Equatable, Sendable {
    let messages: [GmailMessage]
    let nextPageToken: String?
    let historyID: String?
}

enum GmailServiceError: LocalizedError, Equatable {
    case notConfigured
    case cancelled
    case missingScopes
    case authorizationRequired
    case reauthorizationRequired
    case rateLimited
    case temporaryUnavailable
    case malformedResponse
    case networkUnavailable
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Gmail is not configured for this build."
        case .cancelled: "Gmail authorization was cancelled."
        case .missingScopes: "Gmail read permission is required."
        case .authorizationRequired: "Gmail authorization is required."
        case .reauthorizationRequired: "Gmail needs to be connected again."
        case .rateLimited: "Gmail temporarily limited sync requests."
        case .temporaryUnavailable: "Gmail is temporarily unavailable."
        case .malformedResponse: "Gmail returned an unreadable message."
        case .networkUnavailable: "Gmail could not be reached."
        case .storageFailure: "Wool could not save the Gmail import."
        }
    }
}

protocol GmailAPIClient {
    func profile(accessToken: String) async throws -> GmailProfile
    func listMessages(accessToken: String, pageToken: String?) async throws -> GmailMessagePage
}

/// Production Gmail REST client. OAuth configuration is intentionally read
/// from Info.plist so client identifiers are supplied per build environment.
struct LiveGmailAPIClient: GmailAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func profile(accessToken: String) async throws -> GmailProfile {
        let data = try await request(path: "users/me/profile", accessToken: accessToken)
        let response = try decoder.decode(ProfileResponse.self, from: data)
        return GmailProfile(email: response.emailAddress, displayName: response.emailAddress)
    }

    func listMessages(accessToken: String, pageToken: String?) async throws -> GmailMessagePage {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "q", value: "in:inbox newer_than:30d"),
            URLQueryItem(name: "pageToken", value: pageToken)
        ].compactMap { $0.value == nil ? nil : $0 }
        guard let url = components.url else { throw GmailServiceError.malformedResponse }
        let listData = try await request(url: url, accessToken: accessToken)
        let list = try decoder.decode(MessageListResponse.self, from: listData)

        var messages: [GmailMessage] = []
        for message in list.messages ?? [] {
            try Task.checkCancellation()
            let detailData = try await request(path: "users/me/messages/\(message.id)", accessToken: accessToken, query: [
                URLQueryItem(name: "format", value: "full")
            ])
            if let detail = try? decoder.decode(MessageResponse.self, from: detailData),
               let mapped = GmailMessage(response: detail) {
                messages.append(mapped)
            }
        }
        return GmailMessagePage(messages: messages, nextPageToken: list.nextPageToken, historyID: nil)
    }

    private func request(path: String, accessToken: String, query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/\(path)")!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw GmailServiceError.malformedResponse }
        return try await request(url: url, accessToken: accessToken)
    }

    private func request(url: URL, accessToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GmailServiceError.malformedResponse }
            switch http.statusCode {
            case 200..<300: return data
            case 401, 403: throw GmailServiceError.authorizationRequired
            case 429: throw GmailServiceError.rateLimited
            case 500..<600: throw GmailServiceError.temporaryUnavailable
            default: throw GmailServiceError.malformedResponse
            }
        } catch let error as GmailServiceError {
            throw error
        } catch is URLError {
            throw GmailServiceError.networkUnavailable
        } catch {
            throw GmailServiceError.temporaryUnavailable
        }
    }
}

private struct ProfileResponse: Decodable {
    let emailAddress: String
}

private struct MessageListResponse: Decodable {
    struct Item: Decodable { let id: String }
    let messages: [Item]?
    let nextPageToken: String?
}

private struct MessageResponse: Decodable {
    let id: String
    let threadId: String?
    let internalDate: String?
    let payload: Payload?

    struct Header: Decodable {
        let name: String
        let value: String
    }

    struct Payload: Decodable {
        let mimeType: String?
        let filename: String?
        let headers: [Header]?
        let body: Body?
        let parts: [Payload]?
    }

    struct Body: Decodable {
        let data: String?
    }
}

private extension GmailMessage {
    init?(response: MessageResponse) {
        let headers = response.payload?.headers ?? []
        func header(_ name: String) -> String {
            headers.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value ?? ""
        }
        let bodyData = Self.bodyData(from: response.payload)
        let body = bodyData.flatMap { Data(base64URLEncoded: $0) }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let timestamp = response.internalDate.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0 / 1_000) }
        self.init(
            id: response.id,
            threadID: response.threadId ?? "",
            subject: header("Subject"),
            sender: header("From"),
            body: body,
            receivedAt: timestamp,
            webURL: "https://mail.google.com/mail/u/0/#inbox/\(response.id)",
            hasAttachments: Self.hasAttachment(in: response.payload)
        )
    }

    static func bodyData(from payload: MessageResponse.Payload?) -> String? {
        guard let payload else { return nil }
        if payload.mimeType == "text/plain", let data = payload.body?.data { return data }
        for part in payload.parts ?? [] {
            if let data = bodyData(from: part) { return data }
        }
        return payload.body?.data
    }

    static func hasAttachment(in payload: MessageResponse.Payload?) -> Bool {
        guard let payload else { return false }
        if !(payload.filename ?? "").isEmpty { return true }
        return (payload.parts ?? []).contains { hasAttachment(in: $0) }
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        normalized += String(repeating: "=", count: (4 - normalized.count % 4) % 4)
        self.init(base64Encoded: normalized)
    }
}

/// Deterministic API client used by unit tests and UI-test fixtures.
struct FixtureGmailAPIClient: GmailAPIClient {
    let profileValue: GmailProfile
    let pages: [[GmailMessage]]

    init(
        profile: GmailProfile = GmailProfile(email: "fixture@gmail.com", displayName: "Fixture Gmail"),
        pages: [[GmailMessage]] = []
    ) {
        self.profileValue = profile
        self.pages = pages
    }

    func profile(accessToken: String) async throws -> GmailProfile { profileValue }

    func listMessages(accessToken: String, pageToken: String?) async throws -> GmailMessagePage {
        let index = Int(pageToken ?? "0") ?? 0
        guard index < pages.count else { return GmailMessagePage(messages: [], nextPageToken: nil, historyID: "fixture-history") }
        let next = index + 1 < pages.count ? String(index + 1) : nil
        return GmailMessagePage(messages: pages[index], nextPageToken: next, historyID: "fixture-history")
    }
}

@MainActor
final class GmailSyncService {
    struct Result: Equatable {
        let imported: Int
        let skipped: Int
    }

    private let apiClient: any GmailAPIClient
    private let now: () -> Date

    init(apiClient: any GmailAPIClient, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.now = now
    }

    func sync(accountIdentifier: String, accessToken: String, in context: ModelContext) async throws -> Result {
        let account = try account(in: context, identifier: accountIdentifier)
        account.status = .syncing
        account.lastSyncAttemptAt = now()
        account.lastErrorCode = nil
        account.lastErrorMessage = nil
        try context.save()

        do {
            let profile = try await apiClient.profile(accessToken: accessToken)
            guard profile.email.caseInsensitiveCompare(accountIdentifier) == .orderedSame else {
                throw GmailServiceError.authorizationRequired
            }

            let checkpoint = try checkpoint(in: context, identifier: accountIdentifier)
            var pageToken = checkpoint.pageToken
            var imported = 0
            var skipped = 0

            repeat {
                try Task.checkCancellation()
                let page = try await fetchPage(accessToken: accessToken, pageToken: pageToken)
                for message in page.messages {
                    if try importIfNeeded(message, accountIdentifier: accountIdentifier, in: context) {
                        imported += 1
                    } else {
                        skipped += 1
                    }
                }
                checkpoint.pageToken = page.nextPageToken
                checkpoint.historyID = page.historyID ?? checkpoint.historyID
                checkpoint.syncMode = .incremental
                checkpoint.updatedAt = now()
                try context.save()
                pageToken = page.nextPageToken
            } while pageToken != nil

            checkpoint.pageToken = nil
            checkpoint.updatedAt = now()
            account.status = .connected
            account.lastSuccessfulSyncAt = now()
            try context.save()
            return Result(imported: imported, skipped: skipped)
        } catch {
            let requiresReauthorization = (error as? GmailServiceError).map { $0 == .authorizationRequired } ?? false
            account.status = requiresReauthorization ? .disconnected : .temporarilyUnavailable
            account.lastErrorCode = String(describing: error)
            account.lastErrorMessage = error.localizedDescription
            try? context.save()
            throw error
        }
    }

    private func account(in context: ModelContext, identifier: String) throws -> GmailAccountRecord {
        let accounts = try context.fetch(FetchDescriptor<GmailAccountRecord>())
        guard let account = accounts.first(where: { $0.accountIdentifier.caseInsensitiveCompare(identifier) == .orderedSame }) else {
            throw GmailServiceError.authorizationRequired
        }
        return account
    }

    private func fetchPage(accessToken: String, pageToken: String?) async throws -> GmailMessagePage {
        var attempt = 0
        while true {
            do {
                return try await apiClient.listMessages(accessToken: accessToken, pageToken: pageToken)
            } catch let error as GmailServiceError
                where error == .rateLimited || error == .temporaryUnavailable || error == .networkUnavailable {
                guard attempt < 2 else { throw error }
                attempt += 1
                try await Task.sleep(for: .milliseconds(250 * (1 << attempt)))
            }
        }
    }

    private func checkpoint(in context: ModelContext, identifier: String) throws -> GmailSyncCheckpointRecord {
        let checkpoints = try context.fetch(FetchDescriptor<GmailSyncCheckpointRecord>())
        if let existing = checkpoints.first(where: { $0.accountIdentifier == identifier }) { return existing }
        let created = GmailSyncCheckpointRecord(accountIdentifier: identifier)
        context.insert(created)
        return created
    }

    private func importIfNeeded(_ message: GmailMessage, accountIdentifier: String, in context: ModelContext) throws -> Bool {
        let records = try context.fetch(FetchDescriptor<GmailImportedMessageRecord>())
        guard !records.contains(where: {
            $0.accountIdentifier == accountIdentifier && $0.gmailMessageID == message.id
        }) else { return false }

        let title = message.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Email from \(message.sender.isEmpty ? "Unknown sender" : message.sender)"
            : message.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = String(message.body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4_000))
        var notes = "From: \(message.sender.isEmpty ? "Unknown sender" : message.sender)"
        if !excerpt.isEmpty { notes += "\n\n\(excerpt)" }
        if message.hasAttachments { notes += "\n\nAttachment included in Gmail." }
        if !message.webURL.isEmpty { notes += "\n\nOpen in Gmail: \(message.webURL)" }

        let task = TaskItem(title: title, notes: notes, status: .inbox)
        context.insert(task)
        context.insert(GmailImportedMessageRecord(
            accountIdentifier: accountIdentifier,
            gmailMessageID: message.id,
            gmailThreadID: message.threadID,
            taskID: task.id,
            sourceURL: message.webURL,
            receivedAt: message.receivedAt,
            subject: message.subject,
            sender: message.sender
        ))
        return true
    }
}
