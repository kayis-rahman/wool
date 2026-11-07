import XCTest
import SwiftData
@testable import Wool

@MainActor
final class GmailSyncPersistenceTests: XCTestCase {
    func testPagedImportPersistsCheckpointAndCanBeReplayedWithoutDuplicates() async throws {
        let marker = UUID().uuidString
        let email = "integration-\(marker)@gmail.com"
        let context = ModelContext(WoolModelContainer.shared)
        context.insert(GmailAccountRecord(accountIdentifier: email, displayName: "Integration Fixture"))
        try context.save()

        let first = GmailMessage(id: "first-\(marker)", threadID: "thread-1", subject: "First \(marker)", sender: "a@example.com", body: "One", receivedAt: nil, webURL: "", hasAttachments: false)
        let second = GmailMessage(id: "second-\(marker)", threadID: "thread-2", subject: "Second \(marker)", sender: "b@example.com", body: "Two", receivedAt: nil, webURL: "", hasAttachments: false)
        let client = FixtureGmailAPIClient(profile: GmailProfile(email: email, displayName: "Integration Fixture"), pages: [[first], [second]])
        let service = GmailSyncService(apiClient: client)

        let result = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)

        XCTAssertEqual(result.imported, 2)
        let checkpoint = try XCTUnwrap(context.fetch(FetchDescriptor<GmailSyncCheckpointRecord>(predicate: #Predicate { $0.accountIdentifier == email })).first)
        XCTAssertNil(checkpoint.pageToken)
        XCTAssertEqual(checkpoint.historyID, "fixture-history")
        let records = try context.fetch(FetchDescriptor<GmailImportedMessageRecord>(predicate: #Predicate { $0.accountIdentifier == email }))
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(Set(records.map(\.gmailMessageID)), Set([first.id, second.id]))

        let replay = try await service.sync(accountIdentifier: email, accessToken: "fixture", in: context)
        XCTAssertEqual(replay.imported, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GmailImportedMessageRecord>(predicate: #Predicate { $0.accountIdentifier == email })).count, 2)
    }

    func testDisconnectPreservesImportedTaskAndSourceRecord() throws {
        let marker = UUID().uuidString
        let email = "integration-\(marker)@gmail.com"
        let context = ModelContext(WoolModelContainer.shared)
        let account = GmailAccountRecord(accountIdentifier: email)
        let task = TaskItem(title: "Imported \(marker)", status: .inbox)
        context.insert(account)
        context.insert(task)
        context.insert(GmailImportedMessageRecord(accountIdentifier: email, gmailMessageID: "message-\(marker)", taskID: task.id))
        try context.save()

        account.status = .disconnected
        account.isEnabled = false
        try context.save()

        let taskID = task.id
        let savedTask = try XCTUnwrap(context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })).first)
        let savedSource = try XCTUnwrap(context.fetch(FetchDescriptor<GmailImportedMessageRecord>(predicate: #Predicate { $0.gmailMessageID == "message-\(marker)" })).first)
        XCTAssertEqual(savedTask.status, .inbox)
        XCTAssertEqual(savedSource.taskID, task.id)
        XCTAssertEqual(account.status, .disconnected)
    }
}
