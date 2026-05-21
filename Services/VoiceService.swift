import Foundation
import AVFoundation
import os
import Observation

/// Wraps AVSpeechSynthesizer for on-device text-to-speech.
/// Required by ARCHITECTURE.md §3 — AVSpeechSynthesizer is on-device by design.
@Observable
@MainActor
final class VoiceService: NSObject {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "VoiceService")

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Speak

    /// Speaks the given text in the specified language using the best available voice.
    func speak(_ text: String, language: SupportedLanguage) {
        guard !text.isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.prefersAssistiveTechnologySettings = false

        isSpeaking = true
        synthesizer.speak(utterance)
        logger.info("Speaking. Language=\(language.rawValue) Length=\(text.count)")
    }

    /// Stops speech immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Voice selection

    /// Prefers premium/neural voices when available, falls back to default.
    private func bestVoice(for language: SupportedLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: language.rawValue) }

        // Prefer premium quality (neural) voices
        if let premium = voices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return voices.first ?? AVSpeechSynthesisVoice(language: language.rawValue)
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            logger.error("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
