# FinGenius AI

**Intelligent Personal Finance Management and Financial Wellness Companion** — an Android app built with Flutter, Firebase and on-device ML for CMP 7003 (Emerging Mobile Applications). The financial-wellness instantiation of the "AI-Driven Smart Lifestyle Companion" brief.

Smart features: receipt OCR with correction, voice expense entry, layered AI categorisation (rules → learned corrections → keywords → Gemini), transparent financial-health score, explainable cash-flow forecasting with uncertainty bands, duplicate detection, subscription detection, payday-aware nudges, offline-first sync, and a safety-validated Gemini assistant via **Firebase AI Logic** (no API key in the app).

## Quick start (new developer)

Prerequisites: Flutter stable (3.24+), Android Studio + SDK 35, JDK 17, Firebase CLI, Node 20+ (rules tests).

```bash
cd fingenius_ai

# 1. Dependencies (version pins could not be verified offline — refresh them)
flutter pub upgrade --major-versions
flutter pub get

# 2. Static checks
dart format --output=none --set-exit-if-changed .
flutter analyze

# 3. Unit + widget tests
flutter test

# 4. Security-rules tests (needs Firebase emulators)
cd rules_test && npm install && npm test && cd ..

# 5. Run on a device/emulator
flutter run

# 6. Builds
flutter build apk --debug
flutter build appbundle --release   # release-signing setup: docs/release_checklist.md
```

Firebase console actions (App Check, AI Logic, rules deploy, deletion extension) are one-time operator steps — follow `docs/setup/firebase_setup.md`.

## Project layout

```
lib/
  app/         theme (tokens), routing, session/DI, feature flags
  core/        errors, utils (Money/Dates/Validators), storage, queue,
               security, analytics, notifications, shared widgets
  features/    authentication, onboarding, dashboard, accounts, transactions,
               budgets, goals, receipt_scanner, ai_assistant, insights,
               reports, bills, subscriptions, notifications, plans, profile
test/          domain + widget tests
rules_test/    Firestore/Storage security-rules tests (Node + emulator)
assets/brand/  vector brand system (Orbit G mark)
docs/          full engineering + academic documentation
tool/          repeatable asset-rendering pipeline
```

Architecture: Clean Architecture, feature-first, MVVM with Riverpod, Repository pattern, offline queue. Diagrams: `docs/architecture.md`.

## Documentation map

Product: `product_requirements.md` · Traceability: `requirements_traceability_matrix.md` · Data model: `firestore_data_model.md` · Security: `threat_model.md`, `security_checklist.md`, `privacy_data_flow.md` · Offline: `offline_strategy.md` · Setup: `setup/firebase_setup.md` · Verification (honest status): `verification_report.md` · Limitations: `known_limitations.md` · Academic pack: `report_outline.md`, `academic_report_draft.md`, `harvard_references.md`, `rubric_evidence_map.md`.

## Honest status

This project was authored in an environment without a Flutter SDK or pub.dev access, so `flutter analyze`, tests, and builds are **written but not yet executed**. Run steps 1–4 above first; expect at most minor version-drift fixes. Full disclosure: `docs/verification_report.md`.

FinGenius AI is an educational financial-wellness tool — not financial advice, and its health score is not a credit score.
