# Security Checklist

| # | Control | Status | Evidence |
|---|---|---|---|
| 1 | Email/password auth + verification | Implemented | `auth_repository.dart`, verify screen |
| 2 | Reauthentication before account deletion | Implemented | `delete_account_screen.dart` |
| 3 | Ownership-based Firestore rules, default-deny | Implemented + tested | `firestore.rules`, `rules_test/firestore.rules.test.mjs` |
| 4 | Storage rules: owner, MIME, size | Implemented + tested | `storage.rules`, `rules_test/storage.rules.test.mjs` |
| 5 | App Check (Play Integrity prod / debug dev) | Code implemented; console registration = operator action | `main.dart`, `docs/setup/firebase_setup.md` |
| 6 | Biometric app lock (opt-in) | Implemented | `biometric_service.dart`, `lock_screen.dart` |
| 7 | Encrypted local storage for sensitive flags | Implemented | `flutter_secure_storage` (EncryptedSharedPreferences) |
| 8 | No sensitive values in logs | Implemented by convention + `avoid_print` lint | `analysis_options.yaml` |
| 9 | FLAG_SECURE on balance screens | Implemented | `secure_screen.dart`, `MainActivity.kt` |
| 10 | Input validation (client) + rules validation (server) | Implemented | `validators.dart`, rules |
| 11 | File handling: MIME/size validation, compression, temp cleanup | Implemented | `receipt_review_screen.dart`, `storage.rules` |
| 12 | Least-privilege permissions (no location/contacts/storage) | Implemented | `AndroidManifest.xml` |
| 13 | HTTPS-only | Implemented | `usesCleartextTraffic="false"`; Firebase SDKs are TLS-only |
| 14 | Request timeouts + retry caps | Implemented | `ai_gateway.dart`, queue backoff |
| 15 | AI rate limiting (client) | Implemented | quota in `ai_gateway.dart` |
| 16 | AI rate limiting (server) | Operator action: AI Logic quotas in console | setup guide §6 |
| 17 | Local data wipe on logout | Implemented | `SessionCleaner`, `HiveBoxes.clearUser` |
| 18 | Consent gates: analytics, AI, notifications | Implemented, default OFF | `preferences_screen.dart` |
| 19 | AI prompt data minimisation | Implemented | `financial_aggregates.dart` |
| 20 | No Gemini API key in app | Implemented (Firebase AI Logic) | `ai_gateway.dart` |
| 21 | Secret scan of repo | Run — see verification report | `docs/verification_report.md` |
| 22 | Google Sign-In disabled until OAuth configured | Flagged OFF | `feature_flags.dart` |
