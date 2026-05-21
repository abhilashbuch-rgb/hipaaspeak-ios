import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self)    private var authManager
    @Environment(SessionManager.self) private var sessionManager
    @Environment(BillingService.self) private var billing

    @State private var showTour        = false
    @State private var showFirstPaywall = false

    var body: some View {
        Group {
            switch authManager.state {
            case .unknown:
                // Brief loading state while Keychain restores session
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    AppLogoLockup(size: .large)
                        .opacity(0.6)
                }

            case .unauthenticated:
                OnboardingView()

            case .needsCredential:
                CredentialGateView()

            case .authenticated:
                MainTabView()
                    .onAppear {
                        // Show paywall on first launch if no access yet.
                        // This gives new users a frictionless path to subscribe
                        // before they hit the interpreter cold.
                        if !TourManager.hasCompleted && !billing.hasAccess {
                            showFirstPaywall = true
                        } else if !TourManager.hasCompleted {
                            showTour = true
                        }
                    }
                    .sheet(isPresented: $showFirstPaywall) {
                        PaywallView()
                            .onDisappear {
                                // Whether they bought or dismissed, show the tour next
                                if !TourManager.hasCompleted {
                                    showTour = true
                                }
                            }
                    }
                    .sheet(isPresented: $showTour) {
                        TourView(isPresented: $showTour)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.state)
        // Face ID gate — full-screen cover, no escape.
        // Fires when the 30-minute session ceiling hits. ARCHITECTURE.md §5.
        .fullScreenCover(isPresented: Binding(
            get:  { sessionManager.pendingReauth },
            set:  { if !$0 { sessionManager.clearPendingReauth() } }
        )) {
            ReauthGateView()
        }
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
