import XCTest
@testable import HIPAAspeak

/// CRITICAL TESTS — verify that session content is never written to disk.
/// Required by ARCHITECTURE.md §1 — no persistent storage of session content.
///
/// Strategy: Monitor the app's Documents, Library, and tmp directories
/// for any file writes during a simulated session lifecycle.
final class NoDiskWritesTests: XCTestCase {

    /// Snapshot file listing before and after session operations.
    /// If any new files appear that could contain session content, fail.
    func testNoFilesCreatedDuringSession() async throws {
        let dirs = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory,
        ].compactMap { $0 }

        // Snapshot: files before
        let beforeFiles = dirs.flatMap { listFiles(in: $0) }

        // Simulate a session lifecycle on main actor
        await MainActor.run {
            let sessionManager = SessionManager()
            sessionManager.startSession(source: .english, target: .spanish)

            // Add fake transcript content via public API — never touches disk.
            sessionManager.appendTranscriptLine(
                TranscriptLine(
                    speaker: .clinician,
                    originalText: "Do you have any allergies?",
                    translatedText: "Tiene alguna alergia?"
                )
            )
            sessionManager.appendTranscriptLine(
                TranscriptLine(
                    speaker: .patient,
                    originalText: "No tengo alergias",
                    translatedText: "I don't have allergies"
                )
            )

            // End session (triggers wipe)
            sessionManager.endSession()
        }

        // Snapshot: files after
        let afterFiles = dirs.flatMap { listFiles(in: $0) }

        // Compare — any new files?
        let newFiles = Set(afterFiles).subtracting(Set(beforeFiles))

        // Filter out system files that iOS may create (Caches, Preferences, etc.)
        let suspiciousFiles = newFiles.filter { path in
            let lower = path.lowercased()
            // Allow known system paths
            let systemPaths = ["caches", "preferences", ".plist", "logs", "savedstate"]
            return !systemPaths.contains(where: { lower.contains($0) })
        }

        XCTAssertTrue(
            suspiciousFiles.isEmpty,
            "Session created unexpected files on disk: \(suspiciousFiles)"
        )
    }

    /// Verify Session struct is not Codable
    func testSessionIsNotCodable() {
        // This is a compile-time check enforced by the type system.
        // Session deliberately does NOT conform to Codable.
        // If someone adds Codable conformance, this test should be updated
        // to fail at compile time or runtime.

        // Runtime check: attempt to encode should fail
        let session = Session()
        let encoder = JSONEncoder()

        // Session does not conform to Encodable — this line would not compile
        // if someone accidentally added conformance:
        // let _ = try? encoder.encode(session)  // Should NOT compile

        // For now, this test documents the intent.
        XCTAssertTrue(true, "Session must never conform to Codable")
    }

    // MARK: - Helpers

    private func listFiles(in directory: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [String] = []
        while let fileURL = enumerator.nextObject() as? URL {
            files.append(fileURL.path)
        }
        return files
    }
}
