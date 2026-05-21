import Foundation

/// In-memory session state. Never conforms to Codable. Never written to disk.
/// Required by ARCHITECTURE.md §1 — no persistent storage of session content.
struct Session {
    let id: UUID = UUID()
    let startedAt: Date = Date()

    /// The source language (clinician speaks)
    var sourceLanguage: SupportedLanguage = .english

    /// The target language (patient speaks)
    var targetLanguage: SupportedLanguage = .spanish

    /// Live transcript lines — exist only in RAM
    var transcriptLines: [TranscriptLine] = []

    /// Whether a session is actively recording
    var isActive: Bool = false

    /// Zeroes all content. Called by SessionManager on every wipe trigger.
    mutating func clear() {
        transcriptLines.removeAll()
        isActive = false
    }
}

struct TranscriptLine: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date = Date()
    let speaker: Speaker
    let originalText: String
    let translatedText: String

    enum Speaker {
        case clinician
        case patient
    }
}
