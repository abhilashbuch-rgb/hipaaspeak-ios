import Foundation
import os
import UIKit
import Observation

/// Enforces all three wipe triggers from ARCHITECTURE.md §5:
///   1. 30-minute hard session ceiling
///   2. Instant wipe on app background
///   3. 5-minute idle timeout (no mic input)
///
/// Also handles screen-recording detection (ARCHITECTURE.md §8).
@Observable
@MainActor
final class SessionManager {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "SessionManager")

    // MARK: - Session state (in-memory only)

    private(set) var session = Session()
    private(set) var isSessionActive = false
    private(set) var isScreenRecording = false

    // MARK: - Timers

    private var hardCeilingTimer: Timer?
    private var idleTimer: Timer?

    private let hardCeilingSeconds: TimeInterval = 30 * 60  // 30 minutes
    private let idleTimeoutSeconds: TimeInterval = 5 * 60   // 5 minutes

    // MARK: - Wipe reasons (for logging — never logs content)

    enum WipeReason: String {
        case hardCeiling = "30min_ceiling"
        case idleTimeout = "5min_idle"
        case appBackgrounded = "app_backgrounded"
        case userEnded = "user_ended"
        case screenRecording = "screen_recording_detected"
    }

    // MARK: - Lifecycle

    init() {
        observeScreenRecording()
        observeBackgroundNotification()
    }

    // MARK: - Start / Stop

    func startSession(source: SupportedLanguage, target: SupportedLanguage) {
        guard !isSessionActive else { return }

        session = Session()
        session.sourceLanguage = source
        session.targetLanguage = target
        session.isActive = true
        isSessionActive = true

        startHardCeilingTimer()
        resetIdleTimer()

        logger.info("Session started. Source=\(source.rawValue) Target=\(target.rawValue)")
    }

    func endSession() {
        wipe(reason: .userEnded)
    }

    /// Called whenever mic input is received — resets the idle timer.
    func recordActivity() {
        resetIdleTimer()
    }

    /// Appends a completed transcript line to the in-memory session.
    /// Required by ARCHITECTURE.md §1 — session content never written to disk.
    func appendTranscriptLine(_ line: TranscriptLine) {
        session.transcriptLines.append(line)
    }

    // MARK: - Wipe (the critical path)

    func wipe(reason: WipeReason) {
        // Zero all session content
        session.clear()
        isSessionActive = false

        // Cancel timers
        hardCeilingTimer?.invalidate()
        hardCeilingTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil

        // Log reason only — never content
        logger.info("Session wiped. Reason=\(reason.rawValue)")
    }

    // MARK: - Hard ceiling timer (30 min)

    private func startHardCeilingTimer() {
        hardCeilingTimer?.invalidate()
        hardCeilingTimer = Timer.scheduledTimer(
            withTimeInterval: hardCeilingSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.wipe(reason: .hardCeiling)
            }
        }
    }

    // MARK: - Idle timer (5 min)

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(
            withTimeInterval: idleTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.wipe(reason: .idleTimeout)
            }
        }
    }

    // MARK: - Screen recording detection (ARCHITECTURE.md §8)

    private func observeScreenRecording() {
        isScreenRecording = UIScreen.main.isCaptured

        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isScreenRecording = UIScreen.main.isCaptured
                if self.isScreenRecording && self.isSessionActive {
                    self.wipe(reason: .screenRecording)
                    self.logger.warning("Screen recording detected during active session — wiped.")
                }
            }
        }
    }

    // MARK: - Background notification (defense-in-depth)

    private func observeBackgroundNotification() {
        NotificationCenter.default.addObserver(
            forName: .sessionShouldWipe,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.wipe(reason: .appBackgrounded)
            }
        }
    }
}
