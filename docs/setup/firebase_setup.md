# Firebase Setup Guide (operator actions)

Project: `fingenius-app-6dfcc` · Android package: `com.msc.fingenius` (validated against `google-services.json` in Phase 0). The client code is production-ready; the console actions below were **not** performed by the build environment and must be completed by the operator. Nothing is faked in-app — unconfigured features stay behind flags.

## 1. Authentication
Console → Authentication → Sign-in method → enable **Email/Password**. That is all the app requires today.

### Google Sign-In (currently disabled — `oauth_client` is empty)
1. `cd android && ./gradlew signingReport` → copy debug + release SHA-1 and SHA-256.
2. Console → Project settings → Your apps → Android → **Add fingerprint** (all four).
3. Download the refreshed `google-services.json` → replace `android/app/google-services.json`.
4. Add the `google_sign_in` package, implement the provider branch in `auth_repository.dart`.
5. Set Remote Config `google_sign_in_enabled = true`.

## 2. Firestore
Create database (production mode, choose region once — irreversible). Deploy rules + indexes:
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## 3. Storage
Enable Storage, then `firebase deploy --only storage`.

## 4. App Check
Console → App Check → register the Android app with **Play Integrity**. Add the debug token printed on first debug run for development devices. Then set enforcement ON for Firestore, Storage, and AI Logic.

## 5. Cloud Messaging
No extra console step for FCM v1. Server-side sends require a backend or console campaigns.

## 6. Firebase AI Logic (Gemini)
Console → AI Logic → get started → **Gemini Developer API** (or Vertex AI if billing enabled). Set per-user/server quotas here (server-side rate limit). App Check enforcement recommended. The client never embeds a Gemini API key.

## 7. Remote Config
Create parameters matching `FeatureFlags.defaults` (`google_sign_in_enabled`, `ai_assistant_enabled`, `ai_model`, `ai_daily_request_limit`, `ai_max_output_tokens`, `ocr_ai_normalization_enabled`, `subscription_detection_enabled`, `voice_entry_enabled`). Defaults in code keep the app working if unset.

## 8. Crashlytics & Analytics
Both auto-enable with the plugins on first release-build run. Analytics remains consent-gated in-app regardless.

## 9. Account-deletion completeness
Install the **Delete User Data** extension (`firebase ext:install firebase/delete-user-data`) configured to purge `users/{UID}` and `receipts/{UID}` on auth deletion. Until installed, subcollection cleanup after account deletion is incomplete (the app deletes the root doc and auth user).

## 10. Emulators (local dev)
```bash
firebase emulators:start        # auth:9099 firestore:8080 storage:9199 ui:4000
```
Rules tests: `cd rules_test && npm install && npm test`.
