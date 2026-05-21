import Foundation
import os

/// Handles clinical credential verification.
/// For v1: NPI verification via the public NPPES API.
/// ARRT, nursing, BLS are manual review via email submission.
actor CredentialService {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "CredentialService")

    // MARK: - NPI Verification (NPPES public API)

    struct NPPESResult: Sendable {
        let npi: String
        let firstName: String
        let lastName: String
        let credential: String
        let state: String
        let isValid: Bool
    }

    /// Looks up an NPI number against the NPPES public API.
    /// This is the only network call in the app that happens during setup (not during a session).
    /// NPPES is a public CMS registry — no PHI is exchanged.
    func verifyNPI(_ npiNumber: String) async throws -> NPPESResult {
        guard npiNumber.count == 10, npiNumber.allSatisfy(\.isNumber) else {
            throw CredentialError.invalidNPIFormat
        }

        let url = URL(string: "https://npiregistry.cms.hhs.gov/api/?number=\(npiNumber)&version=2.1")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CredentialError.networkError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let resultCount = json?["result_count"] as? Int ?? 0

        guard resultCount > 0,
              let results = json?["results"] as? [[String: Any]],
              let first = results.first,
              let basic = first["basic"] as? [String: Any] else {
            throw CredentialError.npiNotFound
        }

        let firstName = basic["first_name"] as? String ?? ""
        let lastName = basic["last_name"] as? String ?? ""
        let credential = basic["credential"] as? String ?? ""

        // Get practice state from address
        let addresses = first["addresses"] as? [[String: Any]] ?? []
        let practiceAddress = addresses.first { ($0["address_purpose"] as? String) == "LOCATION" }
        let state = practiceAddress?["state"] as? String ?? ""

        logger.info("NPI lookup completed. Valid=true")

        return NPPESResult(
            npi: npiNumber,
            firstName: firstName,
            lastName: lastName,
            credential: credential,
            state: state,
            isValid: true
        )
    }

    // MARK: - Manual credential submission (ARRT, Nursing, BLS)
    // For v1, these are submitted via email for manual review.
    // The uploaded document is stored temporarily with isExcludedFromBackup = true,
    // encrypted, and deleted after the email is sent.

    enum CredentialError: LocalizedError {
        case invalidNPIFormat
        case npiNotFound
        case networkError

        var errorDescription: String? {
            switch self {
            case .invalidNPIFormat:
                return "NPI must be exactly 10 digits."
            case .npiNotFound:
                return "No provider found with that NPI number. Please check and try again."
            case .networkError:
                return "Could not connect to the NPI registry. Please check your internet connection."
            }
        }
    }
}
