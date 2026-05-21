import XCTest
@testable import HIPAAspeak

/// CRITICAL TESTS — verify all three wipe triggers clear session memory.
/// Required by ARCHITECTURE.md §5 and pre-release compliance checklist.
@MainActor
final class SessionWipeTests: XCTestCase {

    private var sessionManager: SessionManager!

    override func setUp() {
        super.setUp()
        sessionManager = SessionManager()
    }

    override func tearDown() {
        sessionManager = nil
        super.tearDown()
    }

    // MARK: - Wipe clears all content

    func testWipeClearsTranscriptLines() {
        sessionManager.startSession(source: .english, target: .spanish)
        // Simulate adding transcript content via the public API.
        sessionManager.appendTranscriptLine(
            TranscriptLine(
                speaker: .clinician,
                originalText: "Test content",
                translatedText: "Contenido de prueba"
            )
        )
        XCTAssertFalse(sessionManager.session.transcriptLines.isEmpty)

        sessionManager.wipe(reason: .userEnded)

        XCTAssertTrue(sessionManager.session.transcriptLines.isEmpty,
                       "Wipe must clear all transcript lines")
    }

    func testWipeDeactivatesSession() {
        sessionManager.startSession(source: .english, target: .spanish)
        XCTAssertTrue(sessionManager.isSessionActive)

        sessionManager.wipe(reason: .appBackgrounded)

        XCTAssertFalse(sessionManager.isSessionActive,
                        "Session must be inactive after wipe")
        XCTAssertFalse(sessionManager.session.isActive,
                        "Session.isActive must be false after wipe")
    }

    // MARK: - Each trigger calls wipe

    func testBackgroundTriggerWipes() {
        sessionManager.startSession(source: .english, target: .spanish)
        sessionManager.wipe(reason: .appBackgrounded)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    func testIdleTriggerWipes() {
        sessionManager.startSession(source: .english, target: .spanish)
        sessionManager.wipe(reason: .idleTimeout)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    func testHardCeilingTriggerWipes() {
        sessionManager.startSession(source: .english, target: .spanish)
        sessionManager.wipe(reason: .hardCeiling)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    func testScreenRecordingTriggerWipes() {
        sessionManager.startSession(source: .english, target: .spanish)
        sessionManager.wipe(reason: .screenRecording)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    // MARK: - Wipe is idempotent

    func testDoubleWipeDoesNotCrash() {
        sessionManager.startSession(source: .english, target: .spanish)
        sessionManager.wipe(reason: .userEnded)
        sessionManager.wipe(reason: .appBackgrounded)
        XCTAssertFalse(sessionManager.isSessionActive)
    }

    func testWipeOnInactiveSessionDoesNotCrash() {
        // No session started
        sessionManager.wipe(reason: .appBackgrounded)
        XCTAssertFalse(sessionManager.isSessionActive)
    }
}
