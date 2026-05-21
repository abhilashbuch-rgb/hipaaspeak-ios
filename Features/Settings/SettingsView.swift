import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AuthManager.self)    private var authManager
    @Environment(BillingService.self) private var billing

    @AppStorage("autoStartRecording") private var autoStartEnabled = false
    @State private var showSignOutConfirm = false
    @State private var showTour          = false
    @State private var showPaywall       = false

    var body: some View {
        NavigationStack {
            List {
                profileHeader
                subscriptionSection
                interpreterSection
                privacySection
                languagesSection
                supportSection
                aboutSection
                signOutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) { authManager.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to use the interpreter.")
            }
            .sheet(isPresented: $showTour)     { TourView(isPresented: $showTour) }
            .sheet(isPresented: $showPaywall)  { PaywallView() }
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar — asterisk in brand color
                ZStack {
                    Circle()
                        .fill(billing.isSubscribed
                              ? Color(red: 0.83, green: 0.67, blue: 0.11).opacity(0.15)
                              : AppLogo.brandPurple.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Text("✳︎")
                        .font(.title2)
                        .foregroundStyle(billing.isSubscribed
                                         ? Color(red: 0.83, green: 0.67, blue: 0.11)
                                         : AppLogo.brandPurple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let credType = authManager.credential?.type {
                        Text(credType.rawValue)
                            .font(.headline)
                    } else {
                        Text("Clinician")
                            .font(.headline)
                    }

                    // NPI last four — shown only for NPI-verified users
                    if let last4 = authManager.credential?.npiLastFour {
                        Text("NPI ••••\(last4)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Verified")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Plan badge
                Text(planBadgeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(planBadgeColor)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 6)
        }
    }

    private var planBadgeText: String {
        if billing.isSubscribed       { return "Subscribed" }
        if billing.hasDaySession      { return "Day Session" }
        return "Free"
    }

    private var planBadgeColor: Color {
        if billing.isSubscribed  { return Color(red: 0.83, green: 0.67, blue: 0.11) }
        if billing.hasDaySession { return AppLogo.brandPurple }
        return Color(.systemGray2)
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section {
            if billing.isSubscribed {
                // Active subscriber
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active subscription")
                            .font(.subheadline.weight(.medium))
                        Text("Unlimited sessions, every day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(Color(red: 0.83, green: 0.67, blue: 0.11))
                }

                Button {
                    // Opens iOS subscription management
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "arrow.up.right")
                        .foregroundStyle(AppLogo.brandPurple)
                }

            } else if billing.hasDaySession {
                // Day session active
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day session active")
                            .font(.subheadline.weight(.medium))
                        Text(billing.timeRemainingFormatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(
                                billing.daySessionSecondsRemaining < 300 ? .red : .secondary
                            )
                    }
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AppLogo.brandPurple)
                }

                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Monthly", systemImage: "arrow.up.circle")
                        .foregroundStyle(AppLogo.brandPurple)
                }

            } else {
                // No access
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active plan")
                            .font(.subheadline.weight(.medium))
                        Text("Purchase a day session or subscribe to start translating.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showPaywall = true
                } label: {
                    Label("View Plans", systemImage: "cart")
                        .foregroundStyle(AppLogo.brandPurple)
                }
            }

            Button {
                Task { await billing.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Interpreter

    private var interpreterSection: some View {
        Section {
            Toggle("Auto-start recording", isOn: $autoStartEnabled)

            Text("When enabled, the app begins listening immediately when you open the interpreter screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
        } header: {
            Text("Interpreter")
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On-device only")
                        .font(.subheadline.weight(.medium))
                    Text("No audio, text, or translations ever leave this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-wipe enabled")
                        .font(.subheadline.weight(.medium))
                    Text("Sessions clear on background, after 5 min idle, or 30 min max.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(.orange)
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zero analytics on session content")
                        .font(.subheadline.weight(.medium))
                    Text("We never log what is spoken or translated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.blue)
            }
        } header: {
            Text("Privacy")
        }
    }

    // MARK: - Languages

    private var languagesSection: some View {
        Section("Languages") {
            NavigationLink {
                LanguageDownloadView()
            } label: {
                Label("Download Language Models", systemImage: "arrow.down.circle")
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section("Support") {
            Button {
                showTour = true
            } label: {
                Label("Replay tour", systemImage: "play.circle")
                    .foregroundStyle(.primary)
            }

            Link(destination: URL(string: "mailto:support@hipaaspeak.com")!) {
                Label("Contact support", systemImage: "envelope")
            }

            Link(destination: URL(string: "https://hipaaspeak.com/#faq")!) {
                Label("FAQ", systemImage: "questionmark.circle")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://hipaaspeak.com/privacy")!) {
                Label("Privacy Policy", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://hipaaspeak.com/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "mailto:support@hipaaspeak.com?subject=BAA%20Request")!) {
                Label("Request a BAA", systemImage: "signature")
            }
        }
    }

    // MARK: - Sign out

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                showSignOutConfirm = true
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Language download guidance

struct LanguageDownloadView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(AppLogo.brandPurple)
                    .padding(.top, 32)

                Text("Language Models")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(
                        icon: "iphone",
                        title: "Managed by iOS",
                        text: "When you select a new language pair for the first time, iOS prompts you to download the translation model. All models are stored on-device."
                    )

                    InfoRow(
                        icon: "lock.fill",
                        title: "Never sent to the cloud",
                        text: "Models run entirely on the Neural Engine. No internet connection is required during a session."
                    )

                    InfoRow(
                        icon: "gear",
                        title: "For speech recognition",
                        text: "Go to Settings → General → Keyboard → Dictation Languages to download on-device speech models for your target languages."
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoRow: View {
    let icon:  String
    let title: String
    let text:  String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppLogo.brandPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
