# HIPAAspeak* — Architecture

**Version:** 1.0
**Last updated:** April 29, 2026

## Core principle

Every stage of the translation pipeline — speech recognition, translation, voice synthesis — runs entirely on the iPhone using Apple's on-device ML frameworks. No audio, no text, no translation ever leaves the device during a session.

## Non-negotiables

1. **No persistent storage of session content.** Audio buffers, transcripts, translations exist only in RAM for the active session. Never written to disk.

2. **No third-party SDKs that capture content.** No Firebase, Crashlytics, Sentry, Mixpanel, etc. Only Apple frameworks + Stripe (payments only).

3. **On-device processing only.** `SFSpeechRecognizer.requiresOnDeviceRecognition = true`. Translation framework is on-device. AVSpeechSynthesizer is on-device.

4. **Documents directory excluded from iCloud backup.** Any written files get `isExcludedFromBackup = true`.

5. **Three wipe triggers:**
   - 30-minute hard session ceiling
   - Instant wipe on app background
   - 5-minute idle timeout

6. **Credential-gated access.** Four paths: NPI (provider), ARRT (rad tech), BLS+vouched (MA), state nursing license.

7. **No real PHI in dev/test/docs.** Synthetic data only.

8. **Screenshots disabled during sessions.** Screen recording detected and blocked.

9. **No analytics on session content.** Only non-content events allowed.

10. **Verify before every build.** Network inspector, Instruments, dependency audit.

## Stack

- Swift 5.10+, SwiftUI, iOS 17.4+, iPhone 12+
- MVVM with @Observable, async/await
- SPM only (no CocoaPods/Carthage)
- Apple frameworks: Speech, Translation, AVFoundation, AuthenticationServices, CryptoKit
- Stripe iOS SDK (payments only)
