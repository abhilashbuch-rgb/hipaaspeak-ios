import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Brand mark — purple asterisk
            AppLogoLockup(size: .large)

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield",
                    title: "100% on-device",
                    subtitle: "No audio or text ever leaves your iPhone"
                )
                FeatureRow(
                    icon: "globe",
                    title: "20 languages",
                    subtitle: "Speak, translate, and hear — in real time"
                )
                FeatureRow(
                    icon: "checkmark.seal",
                    title: "Credential-verified",
                    subtitle: "Built for licensed healthcare professionals"
                )
            }
            .padding(.horizontal)

            Spacer()

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
            } onCompletion: { result in
                authManager.handleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 32)

            Text("No personal health information is collected or stored.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppLogo.brandPurple)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
