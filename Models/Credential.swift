import Foundation

/// Represents a clinician's verified credential.
/// Credential *status* is persisted in Keychain (not PHI).
/// Raw credential documents are never stored after verification.
struct Credential {
    let type: CredentialType
    let verifiedAt: Date?
    let status: VerificationStatus
    /// Last 4 digits of NPI — stored in Keychain for display only. Not PHI.
    let npiLastFour: String?

    init(type: CredentialType, verifiedAt: Date?, status: VerificationStatus, npiLastFour: String? = nil) {
        self.type        = type
        self.verifiedAt  = verifiedAt
        self.status      = status
        self.npiLastFour = npiLastFour
    }

    enum CredentialType: String, CaseIterable {
        case npi = "NPI"             // Provider — National Provider Identifier
        case arrt = "ARRT"           // Radiologic Technologist
        case nursingLicense = "RN"   // State nursing license
        case blsVouched = "BLS"      // BLS cert + employer vouch (for MAs)
    }

    enum VerificationStatus: String {
        case pending
        case verified
        case rejected
        case expired
    }
}
