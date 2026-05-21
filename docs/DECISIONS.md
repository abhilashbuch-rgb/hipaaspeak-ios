# Architecture Decision Records

## ADR-001: On-device only — no server-side translation
Date: 2026-04-29
Context: Evaluated Google Cloud Translation, DeepL, and OpenAI for translation quality.
Decision: Use Apple's Translation framework exclusively. It runs on-device with zero network traffic.
Consequences: Translation quality may be lower for some language pairs. Acceptable tradeoff — privacy is the product.

## ADR-002: No Crashlytics or Sentry
Date: 2026-04-29
Context: Need crash reporting for production stability.
Decision: Use Apple's native crash logs via Xcode Organizer only. Third-party crash reporters can capture stack traces containing in-memory variable content, creating non-zero PHI leakage risk.
Consequences: Less rich crash context. Must rely on user reports + Organizer.

## ADR-003: Session struct is not Codable
Date: 2026-04-29
Context: Swift's Codable makes it trivially easy to serialize to disk.
Decision: Session deliberately does not conform to Codable. This is a compile-time enforcement of the no-persistence rule.
Consequences: Cannot accidentally persist session data via JSONEncoder or similar.

## ADR-004: Three wipe triggers with defense-in-depth
Date: 2026-04-29
Context: Need to ensure session data doesn't survive longer than necessary.
Decision: Implement three independent wipe triggers (background, idle, ceiling) plus defense-in-depth via both scenePhase and applicationWillResignActive.
Consequences: Slightly aggressive — users may lose session on accidental background. Acceptable for healthcare context.

## ADR-005: Credential verification via NPPES for providers
Date: 2026-04-29
Context: Need to verify that users are licensed healthcare professionals.
Decision: Use the free public NPPES API for NPI lookup. Other credential types (ARRT, nursing, BLS) use manual email verification in v1.
Consequences: NPI verification is instant. Other roles require 24-hour manual review.

## ADR-006: TranslationSession kept alive via CheckedContinuation
Date: 2026-05-20
Context: Apple's .translationTask modifier provides a TranslationSession valid only within
its closure's scope. HIPAAspeak needs on-demand, per-utterance translation — the clinician
taps to stop speaking, we translate, append the line, speak it — not a one-shot translate.
Decision: TranslationService suspends the .translationTask closure indefinitely using a
stored CheckedContinuation (sessionEndContinuation). A second continuation
(sessionAvailableContinuation) parks any translate() call that arrives before the session
is ready (e.g., user stops speaking before language models finish loading). reset() resumes
both continuations, tearing down the session cleanly on every wipe trigger.
Consequences: Session lifecycle is tightly coupled to the view's .translationTask modifier.
If the view is dismissed and re-presented, configure() must be called again. Acceptable —
the interpreter screen is never dismissed during an active session.

## ADR-007: Pricing model — two tiers, daily session bank
Date: 2026-05-20
Context: Need a pricing model that serves two distinct user types: high-frequency clinicians
(daily users in busy practices) and low-frequency users (per diem nurses, traveling techs,
occasional encounters).
Decision: Two products only.
  1. Day Session — $9.99. Buys a 30-minute time bank valid for the current calendar day
     (valid for 7 days from purchase). Time is deducted in real time during active sessions.
     Unused minutes expire 7 days after purchase — no rollover. Multiple HIPAA sessions allowed within
     the purchased day (the HIPAA 30-min ceiling and the billing bank are independent).
  2. Monthly — $19.99/month auto-renewable subscription. Unlimited sessions.
     Annual billing option at $181.99/year (~20% discount, ~$15.17/month).
Rationale: The Day Session maps naturally to the existing 30-minute HIPAA session ceiling
architecture. A clinician who uses 8 minutes in the morning can return later the same day
and use the remaining 22 minutes without paying again — fair to the user, simple to explain.
Implementation: Session bank state (date + seconds remaining) stored in Keychain.
This is billing state, not PHI — persistent storage is permitted per ARCHITECTURE.md §1.
Monthly subscribers bypass the bank entirely.
Consequences: Need to track elapsed time during active sessions and deduct from Keychain
bank. No midnight rollover edge case. No PAYG per-minute billing — simplifies StoreKit
implementation to one consumable product + one subscription group.
