import SwiftUI
import UIKit

/// Full-screen re-authentication gate shown when the 30-minute session ceiling fires.
/// Required by ARCHITECTURE.md §5. The user cannot start a new session until Face ID
/// (or device passcode) confirms their identity.
///
/// This is a selling point — show it proudly. It proves the architecture is real.
struct ReauthGateView: View {
    @Environment(AuthManager.self)    private var authManager
    @Environment(SessionManager.self) private var sessionManager

    @State private var isAuthenticating = false
    @State private var errorMessage:  String?
    @State private var attempts       = 0
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0

    private let maxAttempts = 3

    var body: some View {
        ZStack {
            // Blurred dark backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 0) {
                Spacer()

                // Lock mark
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 96, height: 96)

                        Image(systemName: "faceid")
                            .font(.system(size: 52, weight: .thin))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                    VStack(spacing: 10) {
                        Text("Session limit reached")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("HIPAAspeak clears all session content\nevery 30 minutes to protect patient privacy.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .opacity(contentOpacity)

                Spacer().frame(height: 56)

                // Auth button
                VStack(spacing: 16) {
                    Button {
                        Task { await authenticate() }
                    } label: {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20, weight: .medium))
                                Image(systemName: "touchid")
                                    .font(.system(size: 18, weight: .medium))
                                    .opacity(0.6)
                            }
                            Text(isAuthenticating ? "Verifying…" : "Authenticate to continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    if attempts >= maxAttempts {
                        Button("Sign out instead") {
                            authManager.signOut()
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                    } else {
                        // Security reassurance
                        Label("All session data has been cleared", systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .opacity(contentOpacity)

                Spacer()

                // HIPAAspeak wordmark at bottom
                AppLogoLockup(size: .small)
                    .opacity(0.35)
                    .padding(.bottom, 40)
                    .opacity(contentOpacity)
            }
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale   = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                contentOpacity = 1.0
            }
            // Auto-trigger Face ID immediately on appear — don't make them tap
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await authenticate()
            }
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        errorMessage = nil

        let success = await authManager.reauthenticate()

        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.25)) {
                sessionManager.clearPendingReauth()
            }
        } else {
            attempts += 1
            UINotificationFeedbackGenerator().notificationOccurred(.error)

            if attempts >= maxAttempts {
                errorMessage = "Authentication failed \(maxAttempts) times. Please sign out and sign back in."
            } else {
                errorMessage = "Authentication failed. \(maxAttempts - attempts) attempt\(maxAttempts - attempts == 1 ? "" : "s") remaining."
            }
        }

        isAuthenticating = false
    }
}
