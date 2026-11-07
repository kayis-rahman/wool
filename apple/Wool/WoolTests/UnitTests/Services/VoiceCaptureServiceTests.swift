import XCTest
@testable import Wool

@MainActor
final class VoiceCaptureServiceTests: XCTestCase {
    func testTranscriptUpdatesAreExposedBeforeStop() async {
        let backend = FakeVoiceCaptureBackend()
        let service = VoiceCaptureService(englishBackend: backend)

        await service.start(language: .english)
        backend.emit("Buy milk")
        await Task.yield()

        XCTAssertEqual(service.state, .recording)
        XCTAssertEqual(service.transcript, "Buy milk")
    }

    func testStopCompletesWithFinalTranscriptWithoutCreatingPersistence() async {
        let backend = FakeVoiceCaptureBackend()
        let service = VoiceCaptureService(englishBackend: backend)

        await service.start(language: .english)
        backend.emit("Call the dentist")
        await Task.yield()
        service.stop()

        XCTAssertEqual(service.state, .completed)
        XCTAssertEqual(service.transcript, "Call the dentist")
    }

    func testCancelDiscardsPartialRecordingState() async {
        let backend = FakeVoiceCaptureBackend()
        let service = VoiceCaptureService(englishBackend: backend)

        await service.start(language: .english)
        backend.emit("Do not save this")
        await Task.yield()
        service.cancel()

        XCTAssertEqual(service.state, .idle)
        XCTAssertEqual(service.transcript, "Do not save this")
    }

    func testInterruptionPreservesPartialTranscriptAndFailsClearly() async {
        let backend = FakeVoiceCaptureBackend()
        let service = VoiceCaptureService(englishBackend: backend)

        await service.start(language: .english)
        backend.emit("Partial thought")
        await Task.yield()
        service.handleInterruption()

        XCTAssertEqual(service.transcript, "Partial thought")
        XCTAssertEqual(service.failure, .interrupted)
    }

    func testMalayalamBridgeFailureIsTypedAndDoesNotCrash() async {
        let service = VoiceCaptureService(
            englishBackend: FakeVoiceCaptureBackend(),
            malayalamBackend: UnavailableMalayalamVoiceCaptureBackend()
        )

        await service.start(language: .malayalam)

        XCTAssertEqual(service.failure, .bridgeOffline)
        XCTAssertFalse(service.isRecording)
    }

    func testNoSpeechTimesOutWithoutProducingATask() async {
        let service = VoiceCaptureService(
            englishBackend: FakeVoiceCaptureBackend(),
            noSpeechTimeoutNanoseconds: 1_000_000
        )

        await service.start(language: .english)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(service.failure, .noSpeechDetected)
        XCTAssertTrue(service.transcript.isEmpty)
    }
}

@MainActor
private final class FakeVoiceCaptureBackend: VoiceCaptureBackend {
    private var transcriptHandler: ((String) -> Void)?
    private var latestTranscript = ""

    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws {
        transcriptHandler = onTranscript
    }

    func emit(_ transcript: String) {
        latestTranscript = transcript
        transcriptHandler?(transcript)
    }

    func stop() -> String { latestTranscript }
    func cancel() { transcriptHandler = nil }
}
