import XCTest
import SwiftData
@testable import Wool

@MainActor
final class QuickCapturePersistenceTests: XCTestCase {
    func testVoiceDraftDoesNotPersistUntilTheNormalCaptureSavePathRuns() async throws {
        let marker = "Voice draft \(UUID().uuidString)"
        let backend = PersistenceTestVoiceBackend()
        let voice = VoiceCaptureService(englishBackend: backend)
        let context = ModelContext(WoolModelContainer.shared)

        await voice.start(language: .english)
        backend.emit(marker)
        await Task.yield()

        let beforeSave = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == marker }))
        XCTAssertTrue(beforeSave.isEmpty)

        let item = TaskItem(title: marker, status: .inbox)
        try CapturePersistenceService.save(item, in: context)
        let afterSave = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == marker }))
        XCTAssertEqual(afterSave.count, 1)
    }

    func testTwoVoiceCapturesWithTheSameTranscriptPersistAsSeparateInboxItems() async throws {
        let marker = "Repeated voice capture \(UUID().uuidString)"
        let firstBackend = PersistenceTestVoiceBackend()
        let secondBackend = PersistenceTestVoiceBackend()
        let firstVoice = VoiceCaptureService(englishBackend: firstBackend)
        let secondVoice = VoiceCaptureService(englishBackend: secondBackend)
        let context = ModelContext(WoolModelContainer.shared)

        await firstVoice.start(language: .english)
        firstBackend.emit(marker)
        await Task.yield()
        firstVoice.stop()

        await secondVoice.start(language: .english)
        secondBackend.emit(marker)
        await Task.yield()
        secondVoice.stop()

        let first = TaskItem(title: firstVoice.transcript, status: .inbox)
        let second = TaskItem(title: secondVoice.transcript, status: .inbox)
        try CapturePersistenceService.save(first, in: context)
        try CapturePersistenceService.save(second, in: context)

        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == marker }))
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.map(\.id)).count, 2)
    }

    func testVoiceCaptureUsesLocalPersistenceWhenOffline() async throws {
        let marker = "Offline voice capture \(UUID().uuidString)"
        let backend = PersistenceTestVoiceBackend()
        let voice = VoiceCaptureService(englishBackend: backend)
        let configuration = WoolModelContainer.configuration(isTesting: true)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
        let context = ModelContext(WoolModelContainer.shared)

        await voice.start(language: .english)
        backend.emit(marker)
        await Task.yield()
        voice.stop()

        let item = TaskItem(title: voice.transcript, status: .inbox)
        try CapturePersistenceService.save(item, in: context)

        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == marker }))
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.status, .inbox)
    }

    func testCaptureSavesLocallyWithCloudKitDisabledForOfflineOperation() throws {
        let configuration = WoolModelContainer.configuration(isTesting: true)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)

        let context = ModelContext(WoolModelContainer.shared)
        let item = CaptureService(allowsFoundationModel: false).processInboxCapture(text: "Call bank")
        try CapturePersistenceService.save(item, in: context)

        let itemID = item.id
        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == itemID }))
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.title, "Call bank")
        XCTAssertEqual(saved.first?.status, .inbox)
    }

    func testRawCaptureRemainsUncategorizedUntilConfirmationIsSaved() throws {
        let marker = UUID().uuidString
        let context = ModelContext(WoolModelContainer.shared)
        let item = TaskItem(title: "Call dentist Tuesday \(marker)", status: .inbox)

        try CapturePersistenceService.save(item, in: context)

        let itemID = item.id
        let persisted = try XCTUnwrap(
            context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == itemID })).first
        )
        XCTAssertEqual(persisted.status, .inbox)
        XCTAssertTrue(persisted.contextTags.isEmpty)
        XCTAssertNil(persisted.dueDate)
        XCTAssertNil(persisted.project)
        XCTAssertTrue(persisted.areas?.isEmpty ?? true)
    }

    func testRapidDuplicateCapturesRemainSeparateRecords() throws {
        let marker = UUID().uuidString
        let text = "Test \(marker)"
        let service = CaptureService(allowsFoundationModel: false)
        let context = ModelContext(WoolModelContainer.shared)
        let first = service.processInboxCapture(text: text)
        let second = service.processInboxCapture(text: text)

        try CapturePersistenceService.save(first, in: context)
        try CapturePersistenceService.save(second, in: context)

        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == text }))
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.map(\.id)).count, 2)
    }

    func testTenSequentialCapturesAreAllPersisted() throws {
        let marker = UUID().uuidString
        let context = ModelContext(WoolModelContainer.shared)
        let service = CaptureService(allowsFoundationModel: false)

        for index in 1...10 {
            let item = service.processInboxCapture(text: "Rapid capture \(index) \(marker)")
            try CapturePersistenceService.save(item, in: context)
        }

        let saved = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title.contains(marker) }))
        XCTAssertEqual(saved.count, 10)
        XCTAssertTrue(saved.allSatisfy { $0.status == .inbox })
    }

    func testProductionConfigurationUsesPrivateCloudKitForReconnectSync() {
        let configuration = WoolModelContainer.configuration(isTesting: false)

        XCTAssertEqual(configuration.cloudKitContainerIdentifier, WoolModelContainer.cloudKitContainerIdentifier)
        XCTAssertFalse(configuration.isStoredInMemoryOnly)
    }
}

@MainActor
private final class PersistenceTestVoiceBackend: VoiceCaptureBackend {
    private var transcriptHandler: ((String) -> Void)?
    private var transcript = ""

    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws {
        transcriptHandler = onTranscript
    }

    func emit(_ value: String) {
        transcript = value
        transcriptHandler?(value)
    }

    func stop() -> String { transcript }
    func cancel() {}
}
