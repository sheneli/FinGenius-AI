# Firestore Data Model

Ownership strategy: **all user data lives under `users/{uid}/…`**. Rules enforce `request.auth.uid == uid` for the entire subtree — no cross-user reads are expressible. Every document carries `schemaVersion` (int) and `updatedAt` (server timestamp). Money is stored as `amountMinor` (int, minor units) + `currency` (ISO 4217). Serialization via typed `fromMap`/`toMap` converters in each entity (`withConverter` at the datasource).

## Collections

### `users/{uid}`
`email, displayName, createdAt, schemaVersion, prefs{theme, currency, hideBalances, quietStartMin, quietEndMin, paydayDay}, consent{analytics, aiProcessing, notifications, acceptedAt}`

### `users/{uid}/accounts/{accountId}`
`name, type(cash|bank|card|wallet|savings), balanceMinor, currency, archived, createdAt, updatedAt, schemaVersion`

### `users/{uid}/transactions/{txId}`
`type(income|expense), amountMinor, currency, categoryId, accountId, merchant, note, occurredAt, receiptId?, source(manual|ocr|voice|recurring), categoryConfidence?, clientId (uuid for idempotent offline sync), createdAt, updatedAt, schemaVersion`
Indexes: `(occurredAt desc)`, `(type, occurredAt desc)`, `(categoryId, occurredAt desc)`, `(accountId, occurredAt desc)` — see `firestore.indexes.json`.

### `users/{uid}/categories/{categoryId}`
`name, kind(income|expense), iconKey, colorKey, isSeed, sortOrder` (seeded on first login, user-extendable)

### `users/{uid}/budgets/{budgetId}`
`categoryId, periodKey(YYYY-MM), limitMinor, currency, alert80Sent, alert100Sent, createdAt, updatedAt` — one doc per category+period; spent is computed client-side from transactions (single source of truth, no double-write).

### `users/{uid}/goals/{goalId}`
`name, targetMinor, savedMinor, currency, deadline?, iconKey, archived, contributions: [{amountMinor, at, note}] (bounded ≤ 200; overflow rolls into savedMinor)`

### `users/{uid}/bills/{billId}`
`name, amountMinor, currency, categoryId, recurrence(monthly|weekly|yearly|custom days), anchorDate, nextDueAt, autopay, lastPaidAt?, fromSubscriptionId?`

### `users/{uid}/subscriptions/{subId}`
`merchant, normalizedMerchant, amountMinor, intervalDays, confidence(0–1), status(candidate|confirmed|dismissed), evidenceTxIds[≤12], detectedAt`

### `users/{uid}/notifications/{notifId}`
`type(bill|budget|nudge|system|ai), title, body, read, createdAt, payload{}`

### `users/{uid}/receipts/{receiptId}`
`storagePath, merchant?, totalMinor?, taxMinor?, currency?, occurredAt?, ocrConfidence{merchant,total,date}, fingerprint (sha256 of normalized fields), txId?, createdAt`
Storage: `receipts/{uid}/{receiptId}.jpg` (≤ 5 MB, image/jpeg|png|webp only — enforced in `storage.rules`).

### `users/{uid}/ai_conversations/{convId}` + `/messages/{msgId}`
Conversation: `title, createdAt, updatedAt`. Message: `role(user|model), content, createdAt, meta{model, promptTokens?, blocked?}`. Retained max 20 conversations (client-pruned oldest-first).

### `users/{uid}/insights/{insightId}`
`type(spending|forecast|budget|goal|duplicate|subscription), title, body, severity, period, payload{}, dismissed, createdAt`

### `users/{uid}/reports/{YYYY-MM}`
`aggregates{incomeMinor, expenseMinor, savingsMinor, byCategory{}}, aiSummary?, generatedAt`

### `users/{uid}/health_history/{YYYY-MM}`
`score(0–100), factors{savingsRate, budgetAdherence, cashflowStability, emergencyFund, billPunctuality}{value, weight, contribution}, computedAt`

### `users/{uid}/feedback/{feedbackId}`
`kind(categoryCorrection|subscriptionDismiss|insightFeedback), merchant?, fromCategoryId?, toCategoryId?, createdAt` — the learning source for the deterministic categoriser.

### `users/{uid}/devices/{fcmToken}`
`platform, createdAt, lastSeenAt` — pruned on logout.

## Migration planning
`schemaVersion` per doc; a `MigrationRunner` executes idempotent per-doc upgrades lazily on read when `schemaVersion < current`. Migrations registered in `lib/core/storage/migrations.dart`. Breaking cross-doc migrations are release-gated behind Remote Config.

## Conflict & sync
Firestore is source of truth; Hive mirrors reads and queues writes (`clientId` idempotency). Last-write-wins by `updatedAt` (server timestamp); deletes always win. Details: `docs/offline_strategy.md`.
