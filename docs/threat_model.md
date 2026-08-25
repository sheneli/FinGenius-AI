# Threat Model (STRIDE)

Assets: financial transactions, balances, receipts, AI conversations, auth credentials, FCM tokens.

| Threat | Vector | Mitigation | Residual risk |
|---|---|---|---|
| **S**poofing | Stolen credentials | Firebase Auth, email verification, biometric app lock, reauth before deletion | Password reuse by user; recommend strong passwords (validator enforces baseline) |
| Spoofing (client) | Tampered/cloned app calling Firebase APIs | App Check with Play Integrity (release) | Debug provider in dev builds only |
| **T**ampering | Direct Firestore writes bypassing app | Ownership + validation rules (type/range/size checks on money fields, enum types, string caps); default-deny | Rules can't validate business semantics (e.g. plausible-but-wrong amounts) |
| Tampering (local) | Attacker with unlocked device edits Hive files | Android app sandbox; biometric lock; sensitive flags in EncryptedSharedPreferences; local cache holds only the user's own data | Rooted devices weaken sandbox — out of scope |
| **R**epudiation | — | `updatedAt` server timestamps, Crashlytics breadcrumbs (non-sensitive) | No full audit log (v1 scope) |
| **I**nfo disclosure | Cross-user reads | Rules deny all cross-user access (tested in `rules_test/`) | — |
| Info disclosure | Shoulder-surfing / screenshots / recents | Hide-balances toggle, FLAG_SECURE on balance screens | User can disable |
| Info disclosure | Over-sharing with AI | `FinancialAggregates` only — no merchants, notes, or raw transactions in prompts; consent gate | Aggregates still reveal spending scale to the model provider |
| Info disclosure | Logs/analytics leakage | No sensitive values logged; analytics events carry no amounts/merchants; consent-gated | — |
| Info disclosure | Receipt images | Storage rules: owner-only, image MIME, ≤5 MB; compressed before upload; temp files deleted | — |
| **D**oS | AI cost abuse | Per-user daily quota (local) + Remote Config limits + App Check; timeout+retry caps | Server-side per-key quotas are a console action (documented) |
| DoS | Queue flooding | Backoff, poison-op eviction | — |
| **E**levation | Unknown collections/paths | Default-deny final rule in both rule sets | — |

Out of scope v1: rooted-device hardening, certificate pinning (Firebase SDKs pin Google roots), multi-user shared ledgers, server-side anomaly detection.
