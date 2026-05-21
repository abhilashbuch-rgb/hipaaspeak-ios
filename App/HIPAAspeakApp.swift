import SwiftUI

@main
struct HIPAAspeakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var sessionManager = SessionManager()
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionManager)
                .environment(authManager)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Required by ARCHITECTURE.md §5 — wipe on background
            if newPhase == .background {
                sessionManager.wipe(reason: .appBackgrounded)
            }
        }
    }
}
