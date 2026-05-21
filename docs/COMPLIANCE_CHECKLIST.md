# Pre-Release Compliance Checklist

Run this before **every TestFlight build**, not just App Store submission.

## Network isolation
- [ ] Start a full translation session (both directions) with Network Link Conditioner set to "100% loss" — nothing breaks
- [ ] Run session with Xcode Network inspector open — zero traffic during recognition, translation, and speech
- [ ] Verify `SFSpeechRecognizer.requiresOnDeviceRecognition` is `true` in SpeechService.swift

## Disk persistence
- [ ] Run session in Instruments with File Activity profiler — no writes to Documents, Library, or tmp containing session content
- [ ] `NoDiskWritesTests` passes
- [ ] Session struct does NOT conform to Codable

## Memory wipe
- [ ] `SessionWipeTests` all pass
- [ ] Manual test: start session, background app, foreground — transcript is gone
- [ ] Manual test: start session, wait 5 min idle — session clears
- [ ] Manual test: start session, wait 30 min — session clears, Face ID re-auth required

## Screen recording
- [ ] Start session, begin screen recording — session wipes and warning shown
- [ ] Take screenshot during session — screen is blurred

## Dependencies
- [ ] `Package.resolved` audit — no unexpected new dependencies
- [ ] No crash-reporting SDKs (Sentry, Crashlytics, Bugsnag)
- [ ] No analytics SDKs (Firebase, Mixpanel, Amplitude)
- [ ] Only allowed: Apple frameworks + Stripe

## Credential gate
- [ ] Cannot access interpreter without verified credential
- [ ] NPI lookup returns correct provider data
- [ ] Invalid NPI shows clear error

## Accessibility
- [ ] VoiceOver: all buttons, labels, transcript bubbles read correctly
- [ ] Dynamic Type: text scales without clipping
- [ ] Color contrast: meets WCAG AA in both light and dark mode
