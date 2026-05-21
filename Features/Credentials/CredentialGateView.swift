import SwiftUI
import AuthenticationServices

/// Shown after sign-in when the user hasn't verified their clinical credential yet.
/// Required by ARCHITECTURE.md §6 — no translation without verified credentials.
struct CredentialGateView: View {
    @Environment(AuthManager.self) private var authManager

    // Step machine — drives the whole view
    private enum Step {
        case roleSelection
        case npiEntry
        case npiConfirm(CredentialService.NPPESResult)
        case manualInstructions(Credential.CredentialType)
    }

    @State private var step: Step = .roleSelection

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Persistent header
                header

                Divider()

                // Step content
                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case .roleSelection:
                            RoleSelectionStep { role in
                                if role == .npi {
                                    step = .npiEntry
                                } else {
                                    step = .manualInstructions(role)
                                }
                            }
                        case .npiEntry:
                            NPIEntryStep { result in
                                step = .npiConfirm(result)
                            } onBack: {
                                step = .roleSelection
                            }
                        case .npiConfirm(let result):
                            NPIConfirmStep(result: result) {
                                // Confirmed — mark verified
                                let credential = Credential(
                                    type: .npi,
                                    verifiedAt: Date(),
                                    status: .verified
                                )
                                authManager.markCredentialVerified(credential)
                            } onBack: {
                                step = .npiEntry
                            }
                        case .manualInstructions(let role):
                            ManualInstructionsStep(role: role) {
                                step = .roleSelection
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { authManager.signOut() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            AppLogoLockup(size: .small)
                .padding(.top, 20)
            Text("Verify Your Credentials")
                .font(.title3.bold())
            Text("HIPAAspeak is for licensed healthcare professionals only.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// MARK: - Step 1: Role selection

private struct RoleSelectionStep: View {
    let onSelect: (Credential.CredentialType) -> Void

    private let roles: [(Credential.CredentialType, String, String)] = [
        (.npi,            "Provider",                  "MD, DO, NP, PA — verified instantly via NPI registry"),
        (.nursingLicense, "Registered Nurse",          "RN — verified via license upload"),
        (.arrt,           "Radiologic Technologist",   "RT — verified via ARRT certification"),
        (.blsVouched,     "Medical Assistant",         "MA — verified via BLS card + employer confirmation"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is your role?")
                .font(.headline)

            ForEach(roles, id: \.0.rawValue) { role, title, subtitle in
                Button {
                    onSelect(role)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: roleIcon(role))
                            .font(.title3)
                            .foregroundStyle(AppLogo.brandPurple)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func roleIcon(_ role: Credential.CredentialType) -> String {
        switch role {
        case .npi:            "stethoscope"
        case .nursingLicense: "cross.case"
        case .arrt:           "rays"
        case .blsVouched:     "heart.text.square"
        }
    }
}

// MARK: - Step 2a: NPI entry + lookup

private struct NPIEntryStep: View {
    let onResult: (CredentialService.NPPESResult) -> Void
    let onBack:   () -> Void

    @State private var npiInput    = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?

    private let credentialService = CredentialService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton(action: onBack)

            VStack(alignment: .leading, spacing: 6) {
                Text("Enter your NPI")
                    .font(.headline)
                Text("Your 10-digit National Provider Identifier — found on your NPI certificate or at npiregistry.cms.hhs.gov.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("0000000000", text: $npiInput)
                    .keyboardType(.numberPad)
                    .font(.title3.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: npiInput) { _, new in
                        // Clamp to 10 digits only
                        npiInput = String(new.filter(\.isNumber).prefix(10))
                        errorMessage = nil
                    }

                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < npiInput.count ? AppLogo.brandPurple : Color(.systemGray4))
                            .frame(height: 3)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Look Up NPI")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(npiInput.count == 10 ? AppLogo.brandPurple : Color(.systemGray3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(npiInput.count != 10 || isVerifying)
            }

            // Helper link
            HStack {
                Spacer()
                Link("Look up your NPI →",
                     destination: URL(string: "https://npiregistry.cms.hhs.gov")!)
                    .font(.caption)
                    .foregroundStyle(AppLogo.brandPurple)
                Spacer()
            }
        }
    }

    private func verify() async {
        isVerifying = true
        errorMessage = nil
        do {
            let result = try await credentialService.verifyNPI(npiInput)
            onResult(result)
        } catch {
            errorMessage = error.localizedDescription
        }
        isVerifying = false
    }
}

// MARK: - Step 2b: Confirm NPI result

private struct NPIConfirmStep: View {
    let result:    CredentialService.NPPESResult
    let onConfirm: () -> Void
    let onBack:    () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton(action: onBack)

            Text("Is this you?")
                .font(.headline)

            // Provider card
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppLogo.brandPurple.opacity(0.8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.firstName) \(result.lastName)")
                            .font(.title3.bold())

                        if !result.credential.isEmpty {
                            Text(result.credential)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !result.state.isEmpty {
                            Label(result.state, systemImage: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)

                Divider()

                HStack {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("NPI \(result.npi)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Registry match")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppLogo.brandPurple.opacity(0.25), lineWidth: 1)
            )

            Text("By confirming, you certify that you are the licensed provider shown above and agree to use HIPAAspeak only in your professional capacity.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                Button {
                    onConfirm()
                } label: {
                    Text("Yes, that's me — Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppLogo.brandPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onBack()
                } label: {
                    Text("Not me — try a different NPI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Step 3: Manual credentials (ARRT, RN, BLS)

private struct ManualInstructionsStep: View {
    let role:   Credential.CredentialType
    let onBack: () -> Void

    private var roleName: String {
        switch role {
        case .arrt:           "Radiologic Technologist (ARRT)"
        case .nursingLicense: "Registered Nurse"
        case .blsVouched:     "Medical Assistant (BLS)"
        default:              role.rawValue
        }
    }

    private var documentRequired: String {
        switch role {
        case .arrt:           "A photo or scan of your ARRT certification card (front and back)."
        case .nursingLicense: "A photo or scan of your current state nursing license."
        case .blsVouched:     "Your current BLS certification card and a brief note from your supervising clinician confirming your MA role."
        default:              "Relevant credential documentation."
        }
    }

    private var emailSubject: String {
        "Credential Verification – \(roleName)"
    }

    private var emailBody: String {
        """
        Hi HIPAAspeak team,

        I am a \(roleName) and would like to verify my account.

        Please find my credential documentation attached.

        Thank you.
        """
    }

    private var mailtoURL: URL? {
        let subject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body    = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:support@hipaaspeak.com?subject=\(subject)&body=\(body)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BackButton(action: onBack)

            VStack(alignment: .leading, spacing: 6) {
                Text("Manual Verification")
                    .font(.headline)
                Text("We'll review your credential and verify your account within 24 hours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Steps
            VStack(spacing: 12) {
                StepCard(number: "1", title: "Prepare your document",
                         text: documentRequired)
                StepCard(number: "2", title: "Send it to us",
                         text: "Tap below to open an email to support@hipaaspeak.com. Attach your credential photo to the email before sending.")
                StepCard(number: "3", title: "Wait for confirmation",
                         text: "We'll email you within 24 hours to confirm. You'll be able to sign back in and access the interpreter once verified.")
            }

            // Send email button
            if let url = mailtoURL {
                Link(destination: url) {
                    Label("Send Verification Email", systemImage: "envelope.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppLogo.brandPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Text("Your credential documents are used only for verification and are deleted from our systems after review.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Shared sub-components

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.medium))
                Text("Back")
                    .font(.subheadline)
            }
            .foregroundStyle(AppLogo.brandPurple)
        }
    }
}

private struct StepCard: View {
    let number: String
    let title:  String
    let text:   String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppLogo.brandPurple)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
