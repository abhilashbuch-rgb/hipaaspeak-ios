import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showTour = false

    var body: some View {
        Group {
            switch authManager.state {
            case .unknown:
                ProgressView("Loading...")

            case .unauthenticated:
                OnboardingView()

            case .needsCredential:
                CredentialGateView()

            case .authenticated:
                MainTabView()
                    .onAppear {
                        // Show tour on first launch after authentication
                        if !TourManager.hasCompleted {
                            showTour = true
                        }
                    }
                    .sheet(isPresented: $showTour) {
                        TourView(isPresented: $showTour)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.state)
    }
}

/// Tab container for authenticated users
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Interpret", systemImage: "waveform") {
                InterpreterView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tint(AppLogo.brandPurple)
    }
}
