# Privacy Data Flow

## Principles
Data minimisation, on-device first, explicit consent, exportable, deletable. No location, contacts, or advertising identifiers are collected — context-awareness comes from time, payday cycle, calendar and behaviour patterns instead.

## Flows

**Receipt scan:** photo → ML Kit OCR **on device** → parsed fields shown for correction → (only on save) compressed JPEG to `receipts/{uid}/`, metadata to Firestore → temp file deleted. Optional AI normalisation sends **redacted text lines only**, never the image, and only with `consent.aiProcessing`.

**AI assistant:** question + `FinancialAggregates` (month totals, category totals, health score, counts) → Firebase AI Logic → Gemini. Never sent: merchant names, notes, account names, individual transactions, email, display name. Gate: consent toggle + feature flag + per-user daily quota. Conversations stored under the user's own subtree; pruned to 20.

**Voice entry:** platform on-device speech recognition; transcript parsed locally; nothing saved without explicit confirmation. (On some devices the OS speech service may use Google servers — surfaced in the About screen wording.)

**Analytics (opt-in, default OFF):** fixed event names with no monetary values, merchants or free text (`docs/analytics_events.md`). Toggling consent calls `setAnalyticsCollectionEnabled`.

**Crashlytics:** release builds only; no sensitive values are attached to reports.

**Local storage:** per-uid Hive boxes (cache/queue/meta) + EncryptedSharedPreferences for the biometric flag. All deleted on logout and account deletion.

## Data subject rights
Export: Profile → Export my data (JSON full account, CSV transactions), generated on-device. Deletion: Profile → Delete account (reauth required) removes auth user + root doc; full subtree purge via the "Delete User Data" Firebase Extension (operator install step — documented, not faked).

## Retention
AI conversations: max 20, client-pruned. Receipts/transactions: until user deletes. FCM tokens: removed on logout.
