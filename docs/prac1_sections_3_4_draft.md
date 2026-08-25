# PRAC1 — Sections 3 and 4, first draft for review

D. Sheneli Behehsha Munasinghe · Batch 28 · Cardiff Met st20357356 · ICBT CL/MSCIT/28/03

Every technical claim was read from source. File paths given so each is checkable.

---

## 3. Methodology and Development Approach  [342 words]

Requirements were captured as a product specification and a requirements traceability matrix before implementation, with each functional requirement carrying an identifier that later maps to a component and a test. Development followed an iterative, incremental lifecycle organised as vertical slices: each feature was carried from domain model through repository, state and interface before the next began. This suited a single-developer project with a fixed deadline better than a waterfall sequence, because it produced a runnable application early and kept integration risk continuous rather than deferred to the end.

Flutter was selected for the client. Suri et al. (2022) compare Kotlin, React Native and Flutter empirically and find Flutter competitive on rendering performance while offering a single codebase, which matters when development effort rather than platform reach is the binding constraint. Firebase supplies authentication, Firestore, Storage, Messaging, Analytics, Crashlytics, Remote Config and App Check, removing the need to operate server infrastructure for a project of this scope. Two decisions deliberately depart from a pure Firebase design. Receipt text recognition runs on-device through ML Kit rather than in the cloud, following the privacy argument set out by Heydari and Mahmoud (2025); and a Cloudflare Worker mediates the fallback generative provider so that no third-party API key is ever present in the distributed binary.

Traceability from research to system is direct. Each of the four deficits identified in Section 2.6 was treated as a design requirement with a named owning component: opacity answered by provenance-carrying categorisation, point-estimate forecasting by interval reporting with backtesting, vendor-dependent safety by application-side output validation, and data over-collection by prompt minimisation and a least-privilege permission set.

One trade-off is worth stating plainly. The module's learning outcomes name geolocation among the platform capabilities to be demonstrated, and the application ships no location permission at all. This was a deliberate choice: location adds contextual precision at a privacy cost that Magoulas and Polykalas (2026) show is routinely underestimated, and the same contextual work is done temporally through payday anchoring, month windows and bill horizons. Section 5 evaluates whether that trade was worth making.

---

## 4. System Design and Technical Implementation  [828 prose / 850 incl. subheadings]

### 4.1 Architecture

The application follows Clean Architecture organised feature-first, with presentation, domain and data layers inside each of sixteen feature modules under `lib/features/`, and cross-cutting concerns in `lib/core/`. State management uses Riverpod in an MVVM arrangement, where providers expose view models and widgets remain declarative. Navigation is declarative through GoRouter: a `StatefulShellRoute.indexedStack` hosts the five primary tabs so each retains its own navigation stack, and a top-level `redirect` guard enforces the authentication, email-verification and app-lock gates before any protected route resolves (`lib/app/routing/router.dart`). *(Figure 1: layered architecture. Figure 2: navigation graph.)*

Frontend and backend are separated by a repository boundary. No widget touches Firestore directly; every collection is reached through `OwnedCollectionRepository<T>`, a generic repository parameterised by entity type and serialisation functions.

### 4.2 Data layer and offline behaviour

`OwnedCollectionRepository` implements an offline-first contract. Reads stream Firestore snapshots as server truth while mirroring into a Hive box, and serve the mirror on cold offline start or stream error. Writes are optimistic: the entity is written locally and an operation is appended to `PendingQueue`, which flushes to Firestore with exponential backoff. Queued operations carry a UUID `opId` and are applied as idempotent merge-sets or deletes, so replay after a failed flush cannot duplicate data. Conflicts resolve last-write-wins on a server `updatedAt` timestamp, with deletes taking precedence. A fifteen-second per-operation timeout prevents a single hung write from blocking the queue, and queue depth is exposed as a stream so the interface can report pending changes. *(Figure 3: offline write path. Appendix D: queue implementation.)*

### 4.3 Intelligence layer

Categorisation is a four-layer strategy pipeline in `insights/domain/categorizer.dart`: user-defined rules (confidence 0.98), learned corrections from prior user fixes (0.90), a deterministic keyword map seeded with Sri Lankan merchants including Keells, Cargills, PickMe, Dialog and CEB (0.70), and a low-confidence fallback (0.10). Every result carries its category, a confidence value and a `source` string, so the interface can show why a label was chosen. Corrections are recorded through `learn()` and feed layer two, giving the contestability that Starke et al. (2024) identify as a user expectation and the correction loop that Dogru and Kramer (2025) associate with appropriate reliance. Only results below 0.5 confidence are eligible for the generative layer, so most categorisation never leaves the device.

Cash-flow forecasting uses Holt's linear exponential smoothing over monthly totals, a method Petropoulos et al. (2022) confirm remains competitive. Rather than reporting a point estimate, `forecast()` derives an approximately 80% interval from the standard deviation of historical one-step errors, scaled by the square root of the horizon, and returns a `confidence` band of low, medium or high determined by history length and relative error. A `backtest()` method replays one-step forecasts against actuals and the result is displayed to the user, which operationalises the uncertainty communication that Leffrang and Muller (2025) show changes reliance behaviour. *(Figure 4: forecast with uncertainty band and backtest panel.)*

The financial-health score is a transparent weighted composite of savings rate (0.30), budget adherence (0.25), cash-flow stability (0.20), emergency fund (0.15) and bill punctuality (0.10). Each factor is returned individually with its own value, weight, contribution and improvement hint, and the interface labels the result explicitly as not a credit score. Subscription detection requires at least three occurrences of a normalised merchant at a near-regular interval within 20% and amounts within 15% of the median; candidates are surfaced for confirmation and never committed automatically. This mirrors the recurring-transaction filtering that Ibrain and Hernandez (2024) show improves personal forecasting.

### 4.4 Generative layer and its constraints

Gemini is reached through Firebase AI Logic, so no model API key ships in the application and requests are attested by Firebase Authentication and App Check. Prompts contain only a `FinancialAggregates` block — monthly totals, per-category sums, counts and the health score. Merchants, notes, account names and individual transactions are never transmitted. Responses pass `AiOutputValidator` before display: prose is rejected if it promises guaranteed returns or issues direct trade instructions, and structured responses are schema-validated against known category identifiers and plausible ranges. Because Luo et al. (2026) demonstrate that provider-side guardrails can be bypassed, this validation sits in the application rather than being delegated upstream.

Failure is treated as a design case. A per-user daily quota is consumed only on success. When Gemini fails, the same prompt is retried once through a Cloudflare Worker that verifies the caller's Firebase ID token by RS256 signature against Google's published keys, checking issuer, audience and expiry before forwarding to a free OpenRouter model with a key held as a Worker secret (`server/ai-proxy/src/index.ts`). Errors are mapped to a taxonomy that distinguishes transient conditions worth retrying from permanent ones such as model retirement. *(Figure 5: AI request and fallback sequence.)*

### 4.5 Backend and security boundary

Firestore rules are default-deny with ownership checks on every path under `users/{uid}`, plus server-side type and range validation on money fields, string lengths and enumerated types. Storage rules restrict receipts and profile images to their owner and validate content type and size. The Android manifest declares seven permissions with no location, contacts or external storage, disables cleartext traffic, and suppresses Firebase Messaging, Analytics and Crashlytics auto-initialisation so telemetry begins only after explicit consent.

---

## Notes for review

1. Word counts, measured. S3 = 342 (target 350). S4 = 828 prose / 850 incl. subheadings (target 850, exactly on). Assessed body so far: 2,244 of 3,000, leaving 756 for Sections 5-7 against a planned 800. Only 44 short; absorbs into normal editing. The Section 2 overrun has been recovered by Section 3 coming in under.
2. Five figures referenced. All to be built as native editable Word shapes and connectors, not images: layered architecture, navigation graph, offline write path, forecast/backtest panel, AI fallback sequence.
3. The Cloudflare Worker is stronger evidence than expected. It performs full RS256 verification of the Firebase ID token with issuer, audience and expiry checks, and its own comments explain why: without those checks a token from any other Firebase project would be accepted and the proxy would be open. Earns marks under Criterion 6 (AuthN/AuthZ, 3) and Criterion 3 (Advanced features, 3).
4. HELD FOR SECTION 6 — CONFIRM. The Worker's answersWithText() filter exists because ranking free OpenRouter models by context length once selected two Google Lyria music-generation models, which failed every chat call and produced a user-visible "both AI services are unavailable" error while working chat models sat unused. Excellent concrete "challenge encountered and how it was addressed" for the critical reflection (1 mark directly, supports the 2 for results analysis).
