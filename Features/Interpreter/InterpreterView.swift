import SwiftUI
import Translation

/// The main translation screen — the core of the app.
/// All content here is in-memory only. Wiped on background, idle, or ceiling.
struct InterpreterView: View {
    @Environment(SessionManager.self) private var sessionManager

    @State private var speechService = SpeechService()
    @State private var translationService = TranslationService()
    @State private var voiceService = VoiceService()

    @State private var sourceLanguage: SupportedLanguage = .english
    @State private var targetLanguage: SupportedLanguage = .spanish
    @State private var showLanguagePicker = false
    @State private var activeSpeaker: TranscriptLine.Speaker?
    @State private var errorMessage: String?

    /// Auto-start: when enabled, begins listening as soon as the view appears
    @AppStorage("autoStartRecording") private var autoStartEnabled = false

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
                    AppLogo(size: 22)
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
            .onAppear {
                if autoStartEnabled && !sessionManager.isSessionActive {
                    startAutoSession()
                }
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
        VStack(spacing: 16) {
            Spacer()
            AppLogo(size: 48)
                .opacity(0.3)
            Text("Tap the record button to begin")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }

    // MARK: - Mic controls (liquid glass)

    private var micControls: some View {
        VStack(spacing: 12) {
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

                // Playback / speaker toggle
                GlassButton(
                    icon: voiceService.isSpeaking ? .speakerOff : .speaker,
                    size: 52,
                    isActive: voiceService.isSpeaking
                ) {
                    if voiceService.isSpeaking {
                        voiceService.stop()
                    }
                }
                .accessibilityLabel(voiceService.isSpeaking ? "Stop playback" : "Speaker")

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
                    sessionManager.appendTranscriptLine(line)

                    // Speak the translation aloud on the target language.
                    voiceService.speak(translated, language: targetLang)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

        } else {
            // ── Start: stop the other speaker if needed, then begin recording ──
            if speechService.isListening {
                _ = speechService.stopListening()
            }

            // First tap also starts the session and wires up the translation pipeline.
            if !sessionManager.isSessionActive {
                sessionManager.startSession(source: sourceLanguage, target: targetLanguage)
                translationService.configure(source: sourceLanguage, target: targetLanguage)
            }

            activeSpeaker = speaker
            do {
                try speechService.startListening(locale: language.locale)
                sessionManager.recordActivity()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                activeSpeaker = nil
            }
        }
    }

    private func startAutoSession() {
        // Auto-start defaults to clinician speaking first
        sessionManager.startSession(source: sourceLanguage, target: targetLanguage)
        translationService.configure(source: sourceLanguage, target: targetLanguage)
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
        activeSpeaker = nil
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
