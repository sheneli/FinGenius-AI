# Release & Google Play Checklist

## Signing & secrets
- [ ] Create upload keystore: `keytool -genkey -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
- [ ] `android/key.properties` (gitignored) with store/key passwords; switch `signingConfig` in `app/build.gradle.kts` from debug to release config
- [ ] Register release SHA-1/SHA-256 in Firebase console (App Check/Play Integrity, future OAuth)
- [ ] Confirm no secrets in repo (`docs/verification_report.md` secret scan re-run)

## Quality gates
- [ ] `dart format` / `flutter analyze` clean · all tests green (incl. rules tests)
- [ ] Performance budgets measured and recorded (`docs/performance_budgets.md`)
- [ ] Screenshot review both themes + 200% text (checklist in verification report)
- [ ] Crashlytics verified receiving from a release build
- [ ] App Check enforcement ON (Firestore, Storage, AI Logic)

## Play Console
- [ ] `flutter build appbundle --release`
- [ ] Store listing: 512×512 icon (`dist/play_store_icon_512.png`), feature graphic, screenshots
- [ ] **Data safety form** (from `docs/privacy_data_flow.md`): collects email, financial data (user-provided), photos (receipts, optional); no location; no ads; no data sold; encrypted in transit; deletable
- [ ] Privacy-policy URL (host `privacy_data_flow.md` content)
- [ ] Content rating questionnaire; Finance category; "not a financial advisory service" disclosure in description
- [ ] Target API 35 compliance; internal testing track first

# Environment & Secret Management

Committed (client-distributable): `google-services.json` (protected by rules + App Check), Remote Config defaults, brand assets. Never committed: keystores, `key.properties`, service-account JSONs, any Gemini/server API key (none exist — AI Logic only), App Check debug tokens. CI guidance: store keystore + passwords as encrypted CI secrets; inject `key.properties` at build time; run the secret-scan grep from the verification report as a pipeline step.
