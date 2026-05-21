import SwiftUI

/// Shown after sign-in when the user hasn't verified their clinical credential yet.
/// Required by ARCHITECTURE.md §6 — no translation without verified credentials.
struct CredentialGateView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedRole: Credential.CredentialType?
    @State private var npiInput = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var showManualInfo = false

    private let credentialService = CredentialService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Verify Your Credentials")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("HIPAAspeak is for licensed healthcare professionals only. Select your role to get verified.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Role selection
                VStack(spacing: 12) {
                    ForEach(Credential.CredentialType.allCases, id: \.rawValue) { role in
                        RoleButton(
                            role: role,
                            isSelected: selectedRole == role
                        ) {
                            selectedRole = role
                            errorMessage = nil
                        }
                    }
                }
                .padding(.horizontal)

                // NPI verification (for providers)
                if selectedRole == .npi {
                    VStack(spacing: 12) {
                        TextField("Enter your 10-digit NPI", text: $npiInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button {
                            Task { await verifyNPI() }
                        } label: {
                            if isVerifying {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Verify NPI")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(npiInput.count != 10 || isVerifying)
                        .padding(.horizontal)
                    }
                }

                // Manual verification (ARRT, Nursing, BLS)
                if let role = selectedRole, role != .npi {
                    VStack(spacing: 8) {
                        Text("Manual verification required")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("For \(role.rawValue) credentials, email a copy of your license or certification to get verified. We'll confirm within 24 hours.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Learn More") {
                            showManualInfo = true
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                Button("Sign Out") {
                    authManager.signOut()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom)
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Manual Verification", isPresented: $showManualInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Email a photo of your credential to the verification address shown in Settings. You'll be notified once verified.")
            }
        }
    }

    private func verifyNPI() async {
        isVerifying = true
        errorMessage = nil

        do {
            let result = try await credentialService.verifyNPI(npiInput)
            if result.isValid {
                let credential = Credential(
                    type: .npi,
                    verifiedAt: Date(),
                    status: .verified
                )
                authManager.markCredentialVerified(credential)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isVerifying = false
    }
}

private struct RoleButton: View {
    let role: Credential.CredentialType
    let isSelected: Bool
    let action: () -> Void

    private var roleTitle: String {
        switch role {
        case .npi: "Provider (MD, DO, NP, PA)"
        case .arrt: "Radiologic Technologist"
        case .nursingLicense: "Registered Nurse"
        case .blsVouched: "Medical Assistant"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(roleTitle)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
