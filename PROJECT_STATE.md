# PROJECT_STATE — FinGenius AI

Updated: 2026-07-16 · Phase: **7 (documentation/handover) complete**

## Completed
- Phase 0: workspace audit (`docs/file_audit.md`) — package name validated against Firebase config; empty OAuth client identified → Google Sign-In flagged OFF.
- Phase 1: product requirements, personas, RTM, assumptions.
- Phase 2: architecture diagrams (Mermaid), Firestore model, three logo directions → "Orbit G" implemented as 8 SVG masters + Android adaptive/monochrome/notification/splash assets + repeatable render script (executed: Play-Store 512 PNG, legacy mipmaps, splash rendered).
- Phase 3: Flutter scaffold — pubspec, lints, Android Gradle (Kotlin DSL, `com.msc.fingenius`, minSdk 24/target 35), manifest (least-privilege), MainActivity FLAG_SECURE channel, themes (dark default + light), GoRouter (guards + 5-tab shell), Riverpod session wiring, feature flags via Remote Config.
- Phase 4: all vertical slices — auth (sign-up/in, verify, reset, reauth, delete), onboarding, accounts, transactions (list/detail/add/edit, search, filters, voice entry), dashboard (14 modular sections), budgets, goals (+honest projections), reports (4 chart types + forecast band + backtest), receipt OCR (capture → parse → correct → upload), AI assistant (Firebase AI Logic, validated output, quota, consent gate), insights domain (health score, forecaster, duplicates, subscriptions, categoriser, merchant normaliser), bills + calendar, subscription confirm/dismiss, notifications centre, profile/preferences/security/export/deletion/about.
- Phase 5: firestore.rules + storage.rules (default-deny, validation) with 15 emulator tests; offline queue + conflict policy; biometric lock; App Check bootstrap.
- Phase 6: environment-permitted verification executed (see below). Flutter-dependent checks documented as NOT RUN.
- Phase 7: 30+ docs including academic pack.

## Verification actually run here
- Dart-aware bracket/tokenizer check: 90 files — all balanced.
- Import-resolution check: all relative + package:fingenius_ai imports resolve.
- Secret scan: clean (no keys in lib/docs/test; google-services.json only at android/app/).
- Brand raster pipeline executed; mark visually reviewed at 512px and 24px.

## NOT run (no Flutter SDK / pub.dev in this environment)
`dart format`, `flutter analyze`, `flutter test`, rules `npm test`, debug/release builds, screenshot review. Exact commands: README + `docs/verification_report.md`.

## Key architectural decisions
Android-only, no `firebase_options.dart` (Gradle plugin flow) · money as int minor units · Firestore source of truth + Hive mirror/queue (LWW, deletes win) · layered categorisation with AI only for low confidence · AI prompts carry aggregates only · all flags default-safe.

## Known blockers (operator)
Firebase console: App Check registration, AI Logic enablement, rules deploy, deletion extension, (optional) OAuth for Google Sign-In. No code blockers.

## Remaining work
Run the verification suite on a Flutter workstation; fix any version-drift; capture device screenshots for the report; complete `PERSONAL EVIDENCE REQUIRED` sections in the academic draft.
