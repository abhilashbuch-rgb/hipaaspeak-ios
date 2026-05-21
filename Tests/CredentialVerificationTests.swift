import XCTest
@testable import HIPAAspeak

/// Tests for credential verification flows.
final class CredentialVerificationTests: XCTestCase {

    private let credentialService = CredentialService()

    // MARK: - NPI format validation

    func testRejectsShortNPI() async {
        do {
            _ = try await credentialService.verifyNPI("12345")
            XCTFail("Should reject NPI shorter than 10 digits")
        } catch {
            // Expected
        }
    }

    func testRejectsNonNumericNPI() async {
        do {
            _ = try await credentialService.verifyNPI("123456789A")
            XCTFail("Should reject NPI with non-numeric characters")
        } catch {
            // Expected
        }
    }

    func testRejectsEmptyNPI() async {
        do {
            _ = try await credentialService.verifyNPI("")
            XCTFail("Should reject empty NPI")
        } catch {
            // Expected
        }
    }

    // MARK: - Credential model

    func testCredentialTypes() {
        let types = Credential.CredentialType.allCases
        XCTAssertEqual(types.count, 4)
        XCTAssertTrue(types.contains(.npi))
        XCTAssertTrue(types.contains(.arrt))
        XCTAssertTrue(types.contains(.nursingLicense))
        XCTAssertTrue(types.contains(.blsVouched))
    }

    func testVerificationStatuses() {
        // Verify all statuses exist and are distinct
        let statuses: [Credential.VerificationStatus] = [.pending, .verified, .rejected, .expired]
        XCTAssertEqual(Set(statuses.map(\.rawValue)).count, 4)
    }
}
