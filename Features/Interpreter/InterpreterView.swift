import SwiftUI
import Translation
import UIKit

/// The main translation screen — the core of the app.
/// All content here is in-memory only. Wiped on background, idle, or ceiling.
struct InterpreterView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(BillingService.self) private var billing

    @State private var speechService = SpeechService()
    @State private var translationService = TranslationService()
    @State private var voiceService = VoiceService()

    @State private var sourceLanguage: SupportedLanguage = .english
    @State private var targetLanguage: SupportedLanguage = .spanish
    @State private var showLanguagePicker = false
    @State private var showPaywall = false
    @State private var activeSpeaker: TranscriptLine.Speaker?
    @State private var errorMessage: String?

    // Watermark breathing animation
    @State private var watermarkBreathing = false

    /// Auto-start: when enabled, begins listening as soon as the view appears
    @AppStorage("autoStartRecording") private var autoStartEnabled = false

    private var isRecording: Bool { activeSpeaker != nil && speechService.isListening }

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        AppLogo.brandPurple.opacity(0.03),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Brand watermark — large asterisk, always present, breathes while recording
                AppLogo(size: 360)
                    .opacity(isRecording ? 0.055 : 0.035)
                    .scaleEffect(watermarkBreathing ? 1.04 : 1.0)
                    .blur(radius: 1)
                    .offset(y: -20)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.6), value: isRecording)
                    .onChange(of: isRecording) { _, recording in
                        if recording {
                            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                                watermarkBreathing = true
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                watermarkBreathing = false
                            }
                        }
                    }

                VStack(spacing: 0) {
                    // Language selector bar
                    languageBar

                    // Screen recording warning
                    if sessionManager.isScreenRecording {
                        screenRecordingWarning
                    }

                    // Transcript area
                    if sessionManager.isSessionActive {
                        transcriptView
                    } else {
                        idleView
                    }

                    // Mic controls — liquid glass
                    micControls
                }
            }
            .navigationTitle("Interpret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppLogo(size: 28)
                        .opacity(isRecording ? 1.0 : 0.75)
                        .animation(.easeInOut(duration: 0.4), value: isRecording)
                }
                if sessionManager.isSessionActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End", role: .destructive) {
                            stopEverything()
                            sessionManager.endSession()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .translationTask(translationService.translationConfiguration) { session in
                // Keeps the TranslationSession alive for the full interpretation.
                // See TranslationService.processRequests(session:) — ADR-006.
                await translationService.processRequests(session: session)
            }
            .onChange(of: sessionManager.isSessionActive) { _, isActive in
                // Session was wiped externally (background, idle, or ceiling trigger).
                // Clean up mic and voice so the UI resets cleanly.
                if !isActive { stopEverything() }
            }
            .onChange(of: billing.hasAccess) { _, hasAccess in
                // Day session expired mid-session — stop immediately and show paywall.
                if !hasAccess && sessionManager.isSessionActive {
                    stopEverything()
                    sessionManager.endSession()
                }
            }
            .onAppear {
                if autoStartEnabled && !sessionManager.isSessionActive {
                    startAutoSession()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Language bar

    private var languageBar: some View {
        Button {
            showLanguagePicker = true
        } label: {
            HStack(spacing: 8) {
                Text(sourceLanguage.displayName)
                    .fontWeight(.medium)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(targetLanguage.displayName)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
        }
        .disabled(sessionManager.isSessionActive)
        .padding(.vertical, 12)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                source: $sourceLanguage,
                target: $targetLanguage
            )
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sessionManager.session.transcriptLines) { line in
                        TranscriptBubble(line: line)
                            .id(line.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: line.speaker == .clinician ? .leading : .trailing)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Live transcript (not yet committed)
                    if speechService.isListening && !speechService.currentTranscript.isEmpty {
                        Text(speechService.currentTranscript)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .id("live")
                    }
                }
                .padding()
            }
            .onChange(of: sessionManager.session.transcriptLines.count) {
                if let last = sessionManager.session.transcriptLines.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Idle state

    private var idleView: some View {
        IdleLogoView(errorMessage: errorMessage)
    }

    // MARK: - Mic controls (liquid glass)

    private var micControls: some View {
        VStack(spacing: 12) {
            // Day-session time bank — only visible when the user is on a timed session.
            // Subscribers see nothing here; they have unlimited time.
            if billing.hasDaySession {
                Label(billing.timeRemainingFormatted, systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(
                        billing.daySessionSecondsRemaining < 300 ? .red : .secondary
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .accessibilityLabel("Time remaining in session: \(billing.timeRemainingFormatted)")
            }

            // Speaker labels
            HStack(spacing: 48) {
                Text(sourceLanguage.displayName)
                    .font(.caption2)
                    .foregroundStyle(activeSpeaker == .clinician ? .primary : .secondary)
                    .fontWeight(activeSpeaker == .clinician ? .semibold : .regular)

                Text(targetLanguage.displayName)
                    .font(.caption2)
                    .foregroundStyle(activeSpeaker == .patient ? .primary : .secondary)
                    .fontWeight(activeSpeaker == .patient ? .semibold : .regular)
            }

            // Glass buttons
            HStack(spacing: 40) {
                // Clinician record button — red dot
                GlassButton(
                    icon: activeSpeaker == .clinician && speechService.isListening ? .stop : .record,
                    isActive: activeSpeaker == .clinician && speechService.isListening
                ) {
                    toggleListening(speaker: .clinician, language: sourceLanguage)
                }
                .accessibilityLabel("Record \(sourceLanguage.displayName). \(activeSpeaker == .clinician ? "Recording" : "Tap to start")")

                // Center brand mark — doubles as speaker mute when audio is playing
                BrandCenterButton(isSpeaking: voiceService.isSpeaking) {
                    if voiceService.isSpeaking { voiceService.stop() }
                }
                .accessibilityLabel(voiceService.isSpeaking ? "Stop playback" : "HIPAAspeak")

                // Patient record button — red dot
                GlassButton(
                    icon: activeSpeaker == .patient && speechService.isListening ? .stop : .record,
                    isActive: activeSpeaker == .patient && speechService.isListening
                ) {
                    toggleListening(speaker: .patient, language: targetLanguage)
                }
                .accessibilityLabel("Record \(targetLanguage.displayName). \(activeSpeaker == .patient ? "Recording" : "Tap to start")")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Screen recording warning

    private var screenRecordingWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Screen recording detected — session paused for patient safety.")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.red)
    }

    // MARK: - Actions

    private func toggleListening(speaker: TranscriptLine.Speaker, language: SupportedLanguage) {
        if speechService.isListening && activeSpeaker == speaker {
            // ── Stop: capture transcript, translate, commit, speak ──────────
            let transcript = speechService.stopListening()
            activeSpeaker = nil

            guard !transcript.isEmpty else { return }
            sessionManager.recordActivity()

            // The language we translate INTO (opposite side of the conversation).
            let targetLang = speaker == .clinician ? targetLanguage : sourceLanguage

            Task {
                do {
                    let translated = try await translationService.translate(transcript)

                    // Commit the line to in-memory session — never to disk.
                    // Required by ARCHITECTURE.md §1.
                    let line = TranscriptLine(
                        speaker: speaker,
                        originalText: transcript,
                        translatedText: translated
                    )
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        sessionManager.appendTranscriptLine(line)
                    }

                    // Speak the translation aloud on the target language.
                    voiceService.speak(translated, language: targetLang)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

        } else {
            // ── Billing gate: require active access before starting any session ──
            guard billing.hasAccess else {
                showPaywall = true
                return
            }

            // ── Start: stop the other speaker if needed, then begin recording ──
            if speechService.isListening {
                _ = speechService.stopListening()
            }

            // First tap also starts the session and wires up the translation pipeline.
            if !sessionManager.isSessionActive {
                sessionManager.startSession(source: sourceLanguage, target: targetLanguage)
                translationService.configure(source: sourceLanguage, target: targetLanguage)
                // Start the day-session countdown (no-op for subscribers).
                billing.beginSessionTracking()
            }

            activeSpeaker = speaker
            do {
                try speechService.startListening(locale: language.locale)
                sessionManager.recordActivity()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                errorMessage = nil
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = error.localizedDescription
                activeSpeaker = nil
            }
        }
    }

    private func startAutoSession() {
        // Guard billing access even for auto-start — don't bypass the paywall.
        guard billing.hasAccess else {
            showPaywall = true
            return
        }

        sessionManager.startSession(source: sourceLanguage, target: targetLanguage)
        translationService.configure(source: sourceLanguage, target: targetLanguage)
        // Start day-session countdown (no-op for subscribers).
        billing.beginSessionTracking()

        activeSpeaker = .clinician
        do {
            try speechService.startListening(locale: sourceLanguage.locale)
            sessionManager.recordActivity()
        } catch {
            errorMessage = error.localizedDescription
            activeSpeaker = nil
        }
    }

    private func stopEverything() {
        if speechService.isListening {
            _ = speechService.stopListening()
        }
        voiceService.stop()
        translationService.reset()
        // Stop the day-session timer and save remaining seconds to Keychain.
        billing.endSessionTracking()
        activeSpeaker = nil
    }
}

// MARK: - Idle logo view

private struct IdleLogoView: View {
    let errorMessage: String?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                // Outer pulse ring
                AppLogo(size: 120)
                    .opacity(pulse ? 0 : 0.07)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulse)

                // Inner pulse ring
                AppLogo(size: 120)
                    .opacity(pulse ? 0 : 0.12)
                    .scaleEffect(pulse ? 1.25 : 1.0)
                    .animation(.easeOut(duration: 2.0).delay(0.4).repeatForever(autoreverses: false), value: pulse)

                // Core logo
                AppLogo(size: 72)
                    .opacity(0.75)
            }
            .onAppear { pulse = true }

            VStack(spacing: 6) {
                Text("Ready to interpret")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.7))

                Text("Tap a microphone to begin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Brand center button

/// The purple asterisk lives between the two mic buttons.
/// Tapping it stops audio playback when speaking; otherwise it's purely decorative.
private struct BrandCenterButton: View {
    let isSpeaking: Bool
    let action: () -> Void

    @State private var speakerPulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow when speaking
                if isSpeaking {
                    AppLogo(size: 72)
                        .opacity(speakerPulse ? 0 : 0.15)
                        .scaleEffect(speakerPulse ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: speakerPulse)
                }

                // Glass base
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle().fill(
                            isSpeaking
                                ? AppLogo.brandPurple.opacity(0.12)
                                : AppLogo.brandPurple.opacity(0.06)
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            AppLogo.brandPurple.opacity(isSpeaking ? 0.35 : 0.15),
                            lineWidth: 1
                        )
                    )
                    .frame(width: 56, height: 56)

                // The asterisk
                AppLogo(size: isSpeaking ? 28 : 32)
                    .opacity(isSpeaking ? 0.5 : 0.85)

                // Mute hint when speaking
                if isSpeaking {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppLogo.brandPurple.opacity(0.6))
                        .offset(x: 12, y: -12)
                }
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .onChange(of: isSpeaking) { _, speaking in
            speakerPulse = false
            if speaking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { speakerPulse = true }
            }
        }
        .accessibilityLabel(isSpeaking ? "Stop audio" : "HIPAAspeak")
    }
}

// MARK: - Transcript bubble

private struct TranscriptBubble: View {
    let line: TranscriptLine

    private var isClinician: Bool { line.speaker == .clinician }

    var body: some View {
        VStack(alignment: isClinician ? .leading : .trailing, spacing: 4) {
            Text(line.originalText)
                .font(.body)

            Text(line.translatedText)
                .font(.body)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isClinician ? Color.blue.opacity(0.06) : Color.green.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity, alignment: isClinician ? .leading : .trailing)
    }
}
