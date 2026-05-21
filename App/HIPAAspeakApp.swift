import SwiftUI

@main
struct HIPAAspeakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var sessionManager = SessionManager()
    @State private var authManager = AuthManager()
    @State private var billingService = BillingService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionManager)
                .environment(authManager)
                .environment(billingService)
                .task {
                    // Check subscription status on every launch
                    await billingService.checkEntitlements()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Required by ARCHITECTURE.md §5 — wipe on background
            if newPhase == .background {
                sessionManager.wipe(reason: .appBackgrounded)
                billingService.endSessionTracking()
            }
        }
    }
}
