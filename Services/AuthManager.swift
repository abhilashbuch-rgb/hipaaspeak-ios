import Foundation
import AuthenticationServices
import LocalAuthentication
import os
import Observation

/// Manages authentication state: Apple Sign In + Face ID re-auth.
/// Credential verification status is persisted in Keychain (not PHI).
/// Required by ARCHITECTURE.md §6 — credential-gated access only.
@Observable
@MainActor
final class AuthManager {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "AuthManager")

    enum AuthState: Equatable {
        case unknown
        case unauthenticated
        case needsCredential   // Signed in but no verified clinical credential
        case authenticated     // Signed in + verified credential
    }

    private(set) var state: AuthState = .unknown
    private(set) var userID: String?
    private(set) var credential: Credential?

    init() {
        restoreSession()
    }

    // MARK: - Apple Sign In

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                logger.error("Unexpected credential type")
                return
            }
            let userID = appleIDCredential.user
            self.userID = userID

            // Store user ID in Keychain (not PHI — just an opaque identifier)
            KeychainHelper.save(key: "apple_user_id", value: userID)

            // Check if they have a verified credential
            if hasVerifiedCredential() {
                state = .authenticated
            } else {
                state = .needsCredential
            }

            logger.info("Apple Sign In succeeded.")

        case .failure(let error):
            logger.error("Apple Sign In failed: \(error.localizedDescription)")
            state = .unauthenticated
        }
    }

    func signOut() {
        userID = nil
        credential = nil
        KeychainHelper.delete(key: "apple_user_id")
        KeychainHelper.delete(key: "credential_status")
        KeychainHelper.delete(key: "npi_last_four")
        state = .unauthenticated
        logger.info("User signed out.")
    }

    // MARK: - Face ID re-auth

    /// Re-authenticates the user via Face ID / Touch ID.
    /// Called after 30-minute session ceiling (ARCHITECTURE.md §5).
    func reauthenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.warning("Biometrics unavailable: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Re-authenticate to continue your session"
            )
            return success
        } catch {
            logger.error("Face ID auth failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Credential state

    func markCredentialVerified(_ credential: Credential) {
        self.credential = credential
        KeychainHelper.save(key: "credential_status", value: "verified")
        KeychainHelper.save(key: "credential_type", value: credential.type.rawValue)
        if let last4 = credential.npiLastFour {
            KeychainHelper.save(key: "npi_last_four", value: last4)
        }
        state = .authenticated
        logger.info("Credential verified. Type=\(credential.type.rawValue)")
    }

    private func hasVerifiedCredential() -> Bool {
        KeychainHelper.load(key: "credential_status") == "verified"
    }

    // MARK: - Session restore

    private func restoreSession() {
        guard let userID = KeychainHelper.load(key: "apple_user_id") else {
            state = .unauthenticated
            return
        }

        self.userID = userID

        if hasVerifiedCredential() {
            let typeRaw = KeychainHelper.load(key: "credential_type") ?? ""
            let type    = Credential.CredentialType(rawValue: typeRaw) ?? .npi
            let last4   = KeychainHelper.load(key: "npi_last_four")
            credential  = Credential(type: type, verifiedAt: nil, status: .verified, npiLastFour: last4)
            state = .authenticated
        } else {
            state = .needsCredential
        }
    }
}

// MARK: - Minimal Keychain helper (no PHI — only opaque identifiers and status flags)

/// Shared Keychain helper — used by AuthManager (credentials) and BillingService (day-session bank).
/// Only stores billing state and auth state, never PHI. ARCHITECTURE.md §1.
enum KeychainHelper {

    private static let service = "com.hipaaspeak.app"

    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
