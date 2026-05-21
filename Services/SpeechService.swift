import Foundation
import Speech
import os
import Observation

/// Wraps SFSpeechRecognizer with requiresOnDeviceRecognition = true.
/// Required by ARCHITECTURE.md §3 — on-device processing only.
/// No audio is persisted. Buffers exist only during active recognition.
@Observable
@MainActor
final class SpeechService {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "SpeechService")

    private(set) var isListening = false
    private(set) var currentTranscript = ""
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    // MARK: - Start listening

    /// Begins on-device speech recognition for the given locale.
    /// Throws if on-device recognition is unavailable for the locale.
    func startListening(locale: Locale) throws {
        guard !isListening else { return }

        let speechRecognizer = SFSpeechRecognizer(locale: locale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // CRITICAL: on-device only — no audio leaves the device
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw SpeechError.onDeviceNotSupported
        }

        recognizer = speechRecognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true  // ARCHITECTURE.md §3
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.currentTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopListeningInternal()
                }
            }
        }

        isListening = true
        logger.info("Speech recognition started. Locale=\(locale.identifier) OnDevice=true")
    }

    // MARK: - Stop listening

    func stopListening() -> String {
        let finalTranscript = currentTranscript
        stopListeningInternal()
        return finalTranscript
    }

    private func stopListeningInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
        isListening = false
        currentTranscript = ""
    }

    // MARK: - Errors

    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        case onDeviceNotSupported

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognition is not available for this language."
            case .onDeviceNotSupported:
                return "On-device recognition is not available for this language. Please download the language model in Settings > General > Keyboard."
            }
        }
    }
}
