# Testing Guide

## Layers
1. **Domain unit tests** (`test/domain/`) — pure Dart, no mocks needed: health formula, forecaster (+backtest), duplicate/subscription detectors, categoriser, OCR parser, AI output validator, money/dates, voice parsing, goal projection. Run: `flutter test test/domain`.
2. **Widget tests** (`test/widget/`) — shared components, accessibility semantics, 200% text scale. Run: `flutter test test/widget`.
3. **Security-rules tests** (`rules_test/`) — real rules against the Firestore/Storage emulators: `cd rules_test && npm install && npm test`.
4. **Repository/provider tests** — use `fake_cloud_firestore` + `firebase_auth_mocks` (dev deps included) for `OwnedCollectionRepository` behaviour; extend as needed.
5. **Integration tests** — the ten critical journeys below, against the Emulator Suite (`firebase emulators:start`), never production.

## Critical user journeys (manual/integration checklist)
1. Register → verify email → sign in
2. Add account → add income → add expense
3. Scan receipt → correct values → save (check duplicate prompt on rescan)
4. Create budget → spend into it → 80%/over states render
5. Create goal → contribute twice → projection appears
6. Ask AI a question → grounded reply with disclaimer; rate-limit path after quota
7. Airplane mode → add expense → pending badge → reconnect → badge clears, no duplicate
8. Enable biometric lock → background app → reopen → unlock
9. Export JSON + CSV → files open and contain the data
10. Delete account (wrong password rejected; correct password wipes and signs out)

## Conventions
Never call production Firebase from tests. Never commit golden baselines that were not generated and reviewed on a real device (`docs/known_limitations.md` #10). A test that cannot fail is deleted, not kept for coverage numbers.

# Troubleshooting

| Symptom | Fix |
|---|---|
| `pub get` version solve fails | `flutter pub upgrade --major-versions`; check `docs/dependency_decisions.md` for intent |
| Build fails on `firebase_ai` API | Pin the current major and adapt `AiGateway._model()` only |
| App Check errors in debug | Register the debug token printed at first run (console → App Check) |
| PERMISSION_DENIED from Firestore | Rules not deployed, or accessing another uid's path — see `firestore.rules` |
| AI always "unavailable" | AI Logic not enabled in console, consent toggle off, or Remote Config flag false |
| OCR returns nothing | Poor lighting/blur — manual entry always available; check CAMERA permission |
| Emulator tests hang | Ports 8080/9099/9199 busy — `firebase emulators:start` shows conflicts |
| Notifications never fire | Android 13 permission + consent toggle + quiet hours all gate delivery |
