import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @AppStorage("autoStartRecording") private var autoStartEnabled = false
    @State private var showSignOutConfirm = false
    @State private var showTour = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let credType = authManager.credential?.type {
                        HStack {
                            Text("Credential")
                            Spacer()
                            Text(credType.rawValue)
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section {
                    Toggle("Auto-start recording", isOn: $autoStartEnabled)

                    Text("When enabled, the app begins listening in your language as soon as you open the interpreter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Interpreter")
                }

                Section("Languages") {
                    NavigationLink("Download Language Models") {
                        LanguageDownloadView()
                    }
                }

                Section("Privacy") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("On-device only")
                            Text("No audio, text, or translations leave this device.")
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
                            Text("Sessions clear on background, after 5 min idle, or 30 min max.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Help") {
                    Button("Replay tour") {
                        showTour = true
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("Privacy Policy", destination: URL(string: "https://hipaaspeak.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://hipaaspeak.com/terms")!)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to use the interpreter.")
            }
            .sheet(isPresented: $showTour) {
                TourView(isPresented: $showTour)
            }
        }
    }
}

/// Placeholder — Apple's Translation framework provides its own download UI
/// via the .translationTask modifier. This view guides users there.
struct LanguageDownloadView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppLogo.brandPurple)

            Text("Language models are managed by iOS")
                .font(.headline)

            Text("When you select a language for the first time, iOS will prompt you to download the translation model. Models are stored on-device and never sent to the cloud.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("For speech recognition, go to:\nSettings > General > Keyboard > Dictation Languages")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Languages")
    }
}
