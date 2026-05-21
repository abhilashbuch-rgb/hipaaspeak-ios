import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Disable screenshots/screen recording during active sessions.
        // The actual enforcement happens in SessionManager via UIScreen observation.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Defense-in-depth: scenePhase handler in HIPAAspeakApp.swift is primary.
        // This catches edge cases where scenePhase doesn't fire.
        NotificationCenter.default.post(name: .sessionShouldWipe, object: nil)
    }
}

extension Notification.Name {
    static let sessionShouldWipe = Notification.Name("sessionShouldWipe")
}
