import Foundation
import Observation

enum VoiceCaptureLanguage: String, CaseIterable, Identifiable {
    case english
    case malayalam

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .malayalam: "Malayalam"
        }
    }
}

enum VoiceCaptureState: Equatable {
    case idle
    case requestingPermission
    case recording
    case stopping
    case completed
    case failed(VoiceCaptureError)

    var isRecording: Bool {
        self == .recording || self == .requestingPermission || self == .stopping
    }
}

enum VoiceCaptureError: Error, LocalizedError, Equatable {
    case microphonePermissionDenied
    case speechPermissionDenied
    case unavailable
    case noSpeechDetected
    case bridgeOffline
    case interrupted
    case audioFailure(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied, .speechPermissionDenied:
            "Microphone access is unavailable. You can enable it in Settings or type instead."
        case .unavailable:
            "Voice capture is unavailable on this device."
        case .noSpeechDetected:
            "I didn’t catch that. Try speaking again or type instead."
        case .bridgeOffline:
            "Voice bridge offline. Try English dictation or type instead."
        case .interrupted:
            "Recording stopped because the app was interrupted. Your partial text is still here."
        case .audioFailure:
            "Voice capture stopped unexpectedly. Your partial text is still here."
        }
    }
}

@MainActor
protocol VoiceCaptureBackend: AnyObject {
    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws
    func stop() -> String
    func cancel()
}

@MainActor
@Observable
final class VoiceCaptureService {
    private(set) var state: VoiceCaptureState = .idle
    private(set) var transcript = ""
    private(set) var selectedLanguage: VoiceCaptureLanguage = .english

    private let englishBackend: any VoiceCaptureBackend
    private let malayalamBackend: any VoiceCaptureBackend
    private let noSpeechTimeoutNanoseconds: UInt64
    private var timeoutTask: Task<Void, Never>?
    private var receivedSpeech = false

    init(
        englishBackend: (any VoiceCaptureBackend)? = nil,
        malayalamBackend: (any VoiceCaptureBackend)? = nil,
        noSpeechTimeoutNanoseconds: UInt64 = 5_000_000_000
    ) {
        let testTranscript = ProcessInfo.processInfo.environment["WOOL_UI_TEST_VOICE_TRANSCRIPT"]
        self.englishBackend = englishBackend ?? (testTranscript.map { UITestVoiceCaptureBackend(transcript: $0) } ?? NativeEnglishVoiceCaptureBackend())
        self.malayalamBackend = malayalamBackend ?? UnavailableMalayalamVoiceCaptureBackend()
        self.noSpeechTimeoutNanoseconds = noSpeechTimeoutNanoseconds
    }

    var isRecording: Bool { state.isRecording }
    var failure: VoiceCaptureError? {
        guard case let .failed(error) = state else { return nil }
        return error
    }

    func start(language: VoiceCaptureLanguage) async {
        cancel()
        selectedLanguage = language
        transcript = ""
        receivedSpeech = false
        state = .requestingPermission

        let backend = language == .english ? englishBackend : malayalamBackend
        do {
            try await backend.start(
                language: language,
                onTranscript: { [weak self] text in
                    Task { @MainActor [weak self] in
                        guard let self, self.isRecording else { return }
                        self.transcript = text
                        self.receivedSpeech = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        self.state = .recording
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor [weak self] in
                        self?.finish(with: error)
                    }
                }
            )
            state = .recording
            timeoutTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.noSpeechTimeoutNanoseconds)
                guard !Task.isCancelled, !self.receivedSpeech, self.isRecording else { return }
                self.finish(with: .noSpeechDetected)
            }
        } catch let error as VoiceCaptureError {
            finish(with: error)
        } catch {
            finish(with: .audioFailure(error.localizedDescription))
        }
    }

    func stop() {
        guard isRecording else { return }
        state = .stopping
        timeoutTask?.cancel()
        timeoutTask = nil

        let backend = selectedLanguage == .english ? englishBackend : malayalamBackend
        let finalTranscript = backend.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTranscript.isEmpty {
            transcript = finalTranscript
            state = .completed
        } else {
            finish(with: .noSpeechDetected)
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        englishBackend.cancel()
        malayalamBackend.cancel()
        if isRecording { state = .idle }
    }

    func handleInterruption() {
        guard isRecording else { return }
        let backend = selectedLanguage == .english ? englishBackend : malayalamBackend
        let partial = backend.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        if !partial.isEmpty { transcript = partial }
        finish(with: .interrupted)
    }

    func reset() {
        cancel()
        transcript = ""
        state = .idle
    }

    private func finish(with error: VoiceCaptureError) {
        guard isRecording else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        englishBackend.cancel()
        malayalamBackend.cancel()
        state = .failed(error)
    }
}

#if os(iOS)
import AVFoundation
import Speech

@MainActor
final class NativeEnglishVoiceCaptureBackend: VoiceCaptureBackend {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var latestTranscript = ""
    private var onError: ((VoiceCaptureError) -> Void)?

    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws {
        guard language == .english, let recognizer, recognizer.isAvailable else {
            throw VoiceCaptureError.unavailable
        }

        let microphoneGranted = await AVAudioApplication.requestRecordPermission()
        guard microphoneGranted else { throw VoiceCaptureError.microphonePermissionDenied }
        let speechStatus = await Self.requestSpeechAuthorization()
        guard speechStatus == .authorized else { throw VoiceCaptureError.speechPermissionDenied }

        self.onError = onError
        latestTranscript = ""
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        request = recognitionRequest
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    self?.latestTranscript = text
                    onTranscript(text)
                }
            }
            if error != nil {
                Task { @MainActor [weak self] in
                    self?.onError?(.audioFailure("Speech recognition failed"))
                }
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return latestTranscript
    }

    func cancel() {
        _ = stop()
        onError = nil
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
#else
@MainActor
final class NativeEnglishVoiceCaptureBackend: VoiceCaptureBackend {
    func start(language: VoiceCaptureLanguage, onTranscript: @escaping (String) -> Void, onError: @escaping (VoiceCaptureError) -> Void) async throws {
        throw VoiceCaptureError.unavailable
    }
    func stop() -> String { "" }
    func cancel() {}
}
#endif

@MainActor
final class UnavailableMalayalamVoiceCaptureBackend: VoiceCaptureBackend {
    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws {
        throw VoiceCaptureError.bridgeOffline
    }

    func stop() -> String { "" }
    func cancel() {}
}

@MainActor
private final class UITestVoiceCaptureBackend: VoiceCaptureBackend {
    private let fixtureTranscript: String
    private var currentTranscript = ""

    init(transcript: String) {
        fixtureTranscript = transcript
    }

    func start(
        language: VoiceCaptureLanguage,
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (VoiceCaptureError) -> Void
    ) async throws {
        currentTranscript = fixtureTranscript
        onTranscript(fixtureTranscript)
    }

    func stop() -> String { currentTranscript }
    func cancel() { currentTranscript = "" }
}
