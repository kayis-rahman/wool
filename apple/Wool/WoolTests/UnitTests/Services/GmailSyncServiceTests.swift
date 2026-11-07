import XCTest
import SwiftData
@testable import Wool

@MainActor
final class GmailSyncServiceTests: XCTestCase {
    func testImportPersistsRawInboxItemAndSourceRecord() async throws {
        let marker = UUID().uuidString
        let email = "fixture-\(marker)@gmail.com"
        let context = ModelContext(WoolModelContainer.shared)
        let account = GmailAccountRecord(accountIdentifier: email, displayName: "Fixture")
        context.insert(account)
        try context.save()

        let message = GmailMessage(
            id: "message-\(marker)",
            threadID: "thread-\(marker)",
            subject: "Review request \(marker)",
            sender: "sender@example.com",
            body: "Please review this.",
            receivedAt: Date(timeIntervalSince1970: 100),
            webURL: "https://mail.google.com/mail/u/0/#inbox/message-\(marker)",
            hasAttachments: false
        )
        let service = GmailSyncService(apiClient: FixtureGmailAPIClient(
            profile: GmailProfile(email: email, displayName: "Fixture"),
            pages: [[message]]
        ))

        let result = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)
        let task = try XCTUnwrap(context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == "Review request \(marker)" })).first)
        XCTAssertEqual(task.status, .inbox)
        XCTAssertTrue(task.notes.contains("sender@example.com"))
        let imported = try context.fetch(FetchDescriptor<GmailImportedMessageRecord>(predicate: #Predicate { $0.gmailMessageID == "message-\(marker)" }))
        XCTAssertEqual(imported.count, 1)
    }

    func testRepeatedSyncIsIdempotent() async throws {
        let marker = UUID().uuidString
        let email = "fixture-\(marker)@gmail.com"
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(GmailAccountRecord(accountIdentifier: email))
        try context.save()
        let message = GmailMessage(id: "message-\(marker)", threadID: "thread", subject: "Subject", sender: "sender", body: "Body", receivedAt: nil, webURL: "", hasAttachments: false)
        let service = GmailSyncService(apiClient: FixtureGmailAPIClient(profile: GmailProfile(email: email, displayName: "Fixture"), pages: [[message]]))

        let first = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)
        let second = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)

        XCTAssertEqual(first.imported, 1)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skipped, 1)
        let tasks = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == "Subject" }))
        XCTAssertEqual(tasks.count, 1)
    }

    func testEmptySubjectUsesSenderFallbackAndAttachmentMarker() async throws {
        let marker = UUID().uuidString
        let email = "fixture-\(marker)@gmail.com"
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(GmailAccountRecord(accountIdentifier: email))
        try context.save()
        let message = GmailMessage(id: "message-\(marker)", threadID: "thread", subject: "", sender: "sender@example.com", body: "", receivedAt: nil, webURL: "", hasAttachments: true)
        let service = GmailSyncService(apiClient: FixtureGmailAPIClient(profile: GmailProfile(email: email, displayName: "Fixture"), pages: [[message]]))

        _ = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)

        let task = try XCTUnwrap(context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == "Email from sender@example.com" })).first)
        XCTAssertTrue(task.notes.contains("Attachment included in Gmail."))
    }
}
