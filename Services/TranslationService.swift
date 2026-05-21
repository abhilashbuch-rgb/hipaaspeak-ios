import Foundation
import Translation
import os
import Observation

/// Wraps Apple's Translation framework for on-device translation.
/// Required by ARCHITECTURE.md §3 — Translation framework is on-device by design.
/// No text leaves the device during translation.
///
/// Architecture note: Apple's .translationTask modifier provides a TranslationSession
/// that is only valid within its closure's scope. To support on-demand, per-utterance
/// translation (rather than one-shot), we keep the session alive by suspending the
/// .translationTask closure via a CheckedContinuation, and feed translation work to
/// it through a stored async throwing continuation that callers await directly.
/// — ADR-006
@Observable
@MainActor
final class TranslationService {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "TranslationService")

    private(set) var isTranslating = false

    /// Exposed to the .translationTask view modifier. Set by configure(), cleared by reset().
    private(set) var translationConfiguration: TranslationSession.Configuration?

    // The active Translation session, valid only while processRequests(session:) is suspended.
    private var activeSession: TranslationSession?

    // Resumed when a session becomes available (so a waiting translate() call can proceed).
    private var sessionAvailableContinuation: CheckedContinuation<TranslationSession, Error>?

    // Resumed by reset() to tear down the active session and exit processRequests(session:).
    private var sessionEndContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Configuration

    /// Call once per interpretation session, before the first recording starts.
    func configure(source: SupportedLanguage, target: SupportedLanguage) {
        // Tear down any existing session cleanly.
        sessionEndContinuation?.resume()
        sessionEndContinuation = nil
        activeSession = nil

        // Cancel any translate() call that was waiting for a session that never arrived.
        sessionAvailableContinuation?.resume(throwing: TranslationError.sessionReset)
        sessionAvailableContinuation = nil

        let sourceLocale = Locale.Language(identifier: source.rawValue)
        let targetLocale = Locale.Language(identifier: target.rawValue)
        translationConfiguration = TranslationSession.Configuration(
            source: sourceLocale,
            target: targetLocale
        )

        logger.info("Translation configured. \(source.rawValue) -> \(target.rawValue)")
    }

    // MARK: - Session lifecycle (called by .translationTask modifier in InterpreterView)

    /// Stores the session provided by SwiftUI's .translationTask modifier and suspends
    /// the modifier's Task, keeping the session valid for the duration of the interpretation.
    /// Returns only when reset() is called (session wipe or user ends session).
    func processRequests(session: TranslationSession) async {
        activeSession = session

        // Wake up any translate() call that was waiting for the session to be ready.
        sessionAvailableContinuation?.resume(returning: session)
        sessionAvailableContinuation = nil

        // Suspend here — the session stays valid as long as we don't return.
        // reset() will resume this continuation, ending the task gracefully.
        await withCheckedContinuation { continuation in
            sessionEndContinuation = continuation
        }

        activeSession = nil
        logger.info("Translation session ended.")
    }

    // MARK: - Translate (called from InterpreterView after mic stops)

    /// Translates a single utterance. Waits for the Translation framework to be
    /// ready if language models are still loading (common on first session start).
    func translate(_ text: String) async throws -> String {
        guard !text.isEmpty else { return "" }

        // Get the active session, waiting if it hasn't been provided yet.
        let session: TranslationSession
        if let active = activeSession {
            session = active
        } else {
            // .translationTask fires asynchronously after configure() is called.
            // Park here until processRequests(session:) resumes us.
            session = try await withCheckedThrowingContinuation { continuation in
                sessionAvailableContinuation = continuation
            }
        }

        isTranslating = true
        defer { isTranslating = false }

        let response = try await session.translate(text)

        // Log only lengths — never log content. Required by ARCHITECTURE.md §9.
        logger.info("Translation complete. \(text.count) chars -> \(response.targetText.count) chars")
        return response.targetText
    }

    // MARK: - Reset (called on every session wipe trigger)

    func reset() {
        // Resume the suspension in processRequests(session:), releasing the session.
        sessionEndContinuation?.resume()
        sessionEndContinuation = nil
        activeSession = nil

        // Cancel any in-flight translate() call.
        sessionAvailableContinuation?.resume(throwing: TranslationError.sessionReset)
        sessionAvailableContinuation = nil

        translationConfiguration = nil
        isTranslating = false
    }

    // MARK: - Errors

    enum TranslationError: LocalizedError {
        case sessionReset

        var errorDescription: String? {
            "The translation session was reset. Please start a new session."
        }
    }
}
