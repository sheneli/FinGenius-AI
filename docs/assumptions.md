# Assumptions and Reversible Decisions

| ID | Assumption / decision | Rationale | Reversal cost |
|----|----------------------|-----------|---------------|
| A-01 | Flutter project lives in `fingenius_ai/` inside the workspace | Keeps assessment files at workspace root untouched | Trivial (move folder) |
| A-02 | Android-only; no `firebase_options.dart`. Firebase initialises from `android/app/google-services.json` via the Google Services Gradle plugin | Avoids duplicating config values into Dart source; standard Android-only flow | Low — run `flutterfire configure` if other platforms are ever added |
| A-03 | Default currency LKR with user-selectable currency (ISO 4217 subset); amounts stored as integer minor units | Cardiff Met/ICBT context; integer minor units avoid floating-point money errors | Low |
| A-04 | Email/password is the sole enabled auth provider; Google Sign-In feature-flagged OFF | `oauth_client` is empty in the supplied config; faking it is prohibited | Console action + flag flip |
| A-05 | Hive CE chosen for offline persistence over Drift/sqflite | Pure-Dart, fast typed boxes fit a document-shaped cache mirroring Firestore; a SQL layer adds no value here | Medium — repository interfaces isolate storage |
| A-06 | fl_chart chosen for charts | Mature, actively maintained, Material-3 friendly, no platform channels | Low — charts wrapped in `ChartContainer` |
| A-07 | No location collection | Privacy-preserving context (time, payday cycle, calendar, behaviour patterns) satisfies context-awareness; the brief's SDK LO is met via camera/mic/biometrics/persistent storage | N/A (deliberate) |
| A-08 | AI model default `gemini-2.5-flash`, selected via Remote Config | Cost-effective; switchable without release | Trivial |
| A-09 | On-device ML Kit OCR before any cloud AI call; only normalised, minimised fields ever sent to Gemini | Data minimisation | N/A (deliberate) |
| A-10 | Offline conflict policy: last-write-wins with server timestamp as arbiter; deletions always win | Single-user finance data; concurrent edits rare; see `docs/offline_strategy.md` | Medium |
| A-11 | Financial-health score is a 0–100 weighted composite (formula in `financial_health.dart` and docs), never a credit score | Transparency requirement | Low |
| A-12 | English (en) only shipped locale; l10n scaffolding present | Assessment language; extra ARB files can be added later | Low |
| A-13 | Build verification could not run in this sandbox (no Flutter SDK; pub.dev blocked). All commands documented; results marked NOT RUN | Honesty rules 6–7 | N/A |
| A-14 | Manrope via `google_fonts` (with offline asset-bundling instructions documented) rather than committing font binaries | Prevents fabricating/corrupting font assets; OFL licence documented | Low |
| A-15 | Voice expense entry uses `speech_to_text` (on-device platform speech API) | Audio never leaves the phone by default | Low |
| A-16 | Screenshot protection (FLAG_SECURE) on balance-revealing screens via a MethodChannel toggle | Selective, per spec | Low |
| A-17 | All user data lives under `users/{uid}/…` subcollections | Simplest airtight ownership rule | Medium |
| A-18 | Firestore is the source of truth; Hive is a cache + pending-op queue | Cloud sync requirement | N/A |
