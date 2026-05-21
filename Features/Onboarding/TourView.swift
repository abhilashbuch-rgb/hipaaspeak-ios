import SwiftUI

/// First-time interactive tour shown after sign-in + credential verification.
/// Walks through the core workflow so clinicians feel confident immediately.
/// Can be replayed from Settings.
struct TourView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    private let steps: [TourStep] = [
        TourStep(
            icon: "hand.wave",
            title: "Welcome to HIPAAspeak",
            body: "This quick tour shows you how to use the interpreter. It takes about 30 seconds.",
            accent: AppLogo.brandPurple
        ),
        TourStep(
            icon: "globe",
            title: "Choose languages",
            body: "Tap the language bar at the top to pick your language and your patient's language. We support 20 languages — all translated on-device.",
            accent: .blue
        ),
        TourStep(
            icon: "record.circle",
            title: "Tap to speak",
            body: "Tap the left microphone when you speak. Tap the right microphone when your patient speaks. The app listens, translates, and reads the translation aloud.",
            accent: .red
        ),
        TourStep(
            icon: "lock.shield.fill",
            title: "Everything stays on this device",
            body: "No audio, text, or translations leave your iPhone. Ever. There's no server to hack because the server never sees your conversation. That's the architecture.",
            accent: .green
        ),
        TourStep(
            icon: "timer",
            title: "Automatic session protection",
            body: "Sessions auto-clear when you background the app, after 5 minutes of silence, or after 30 minutes max. Nothing is saved. Nothing persists.",
            accent: .orange
        ),
        TourStep(
            icon: "checkmark.circle.fill",
            title: "You're all set",
            body: "Tap a microphone to start your first interpretation. You can replay this tour anytime from Settings.",
            accent: AppLogo.brandPurple
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? steps[currentStep].accent : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.top, 24)

            Spacer()

            // Step content
            VStack(spacing: 20) {
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 56))
                    .foregroundStyle(steps[currentStep].accent)
                    .id(currentStep) // Force re-render for animation
                    .transition(.scale.combined(with: .opacity))

                Text(steps[currentStep].title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(steps[currentStep].body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            // Navigation
            HStack {
                if currentStep > 0 {
                    GlassPillButton("Back", icon: "chevron.left") {
                        currentStep -= 1
                    }
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    GlassPillButton("Next", icon: "chevron.right") {
                        currentStep += 1
                    }
                } else {
                    Button {
                        TourManager.markComplete()
                        isPresented = false
                    } label: {
                        Text("Get started")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppLogo.brandPurple)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .interactiveDismissDisabled() // Don't let them swipe away the tour
    }
}

private struct TourStep {
    let icon: String
    let title: String
    let body: String
    let accent: Color
}

// MARK: - Tour state (persisted in UserDefaults — no PHI)

enum TourManager {
    private static let key = "hasCompletedTour"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.set(false, forKey: key)
    }
}
