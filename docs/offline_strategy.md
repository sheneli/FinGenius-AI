# Offline Strategy

FinGenius AI is offline-first for core money tracking. Cloud features (auth sign-in, AI, push) require connectivity and the UI says so honestly.

## Architecture

Firestore is the source of truth. Each signed-in user gets three Hive boxes (`cache_<uid>`, `queue_<uid>`, `meta_<uid>`) — per-user isolation on shared devices; all wiped on logout/deletion (`HiveBoxes.clearUser`).

**Reads.** `OwnedCollectionRepository.watchAll()` emits the Hive mirror immediately (cold offline start works), then live Firestore snapshots; every snapshot change updates the mirror. Stream errors fall back to the mirror. Firestore's native offline persistence adds a second safety layer.

**Writes.** Every create/update/delete is (1) applied optimistically to the Hive cache, (2) enqueued as a `PendingOp` (uuid `opId`, doc-level idempotent merge-set/delete), (3) flushed by `PendingQueue.flush()` — triggered on enqueue and on connectivity regain, with exponential backoff (2^n s, capped 60 s). Poison ops (permission-denied/invalid-argument) are dropped rather than blocking the queue. Transaction `clientId` uuids make retried saves idempotent end-to-end.

**UI truth.** Transactions with queued writes render a "pending sync" badge (`TransactionTile`); an offline banner shows in the shell; the queue size is observable (`PendingQueue.size`).

## Conflict policy (documented decision, A-10)

Last-write-wins arbitrated by `updatedAt` server timestamp; queued ops apply as **merge-sets**, so concurrent edits to different fields of one doc merge cleanly. **Deletes win**: a delete op removes the doc regardless of queued edits elsewhere. Rationale: financial records here are single-user, single-writer in practice; complex CRDT merging adds risk without user benefit.

**Known limitation (honest):** if device A deletes a doc while device B has a queued edit for it, B's later merge-set recreates the doc. Mitigation planned for v1.1: tombstone check before flush. Recorded in `docs/known_limitations.md`.

## Feature availability matrix

| Feature | Offline | Notes |
|---|---|---|
| View recent transactions/accounts/budgets/goals | ✅ | Hive mirror |
| Add/edit/delete transactions | ✅ | queued |
| Receipt OCR (on-device) | ✅ | image upload deferred; save proceeds without image |
| Voice entry | ✅ (device-dependent) | on-device speech where supported |
| Sign in / sign up | ❌ | Firebase Auth needs network (session persists once signed in) |
| AI assistant | ❌ | explicit offline message |
| Push notifications | ❌ | local reminders still fire |
| Data export | ✅ | generated from local data |
