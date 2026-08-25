# Requirements Traceability Matrix

Maps every CMP 7003 PRAC1 rubric criterion → product feature → source files → design/test/documentation evidence. FR/NFR IDs refer to `docs/product_requirements.md`.

## 1. Project Content and Innovation (20)

| Sub-criterion | Feature (FR) | Source files | Evidence |
|---|---|---|---|
| Problem identification (5) | Financial-wellness-as-lifestyle framing | — | `docs/product_requirements.md`, report §1–2 |
| Originality (5) | Layered AI (rules → heuristics → Gemini → user confirm); payday-aware nudges; health score with visible factors | `lib/features/insights/domain/*`, `lib/features/ai_assistant/*` | `docs/architecture.md` §AI, report §4 |
| Smart functionality (5) | OCR receipt capture (FR-05), voice entry (FR-06), forecasting (FR-17), subscription detection (FR-12), duplicate detection (FR-15), AI assistant (FR-13) | `lib/features/receipt_scanner/*`, `lib/features/insights/domain/*` | Unit tests in `test/domain/*`, `docs/rubric_evidence_map.md` |
| User value & practicality (5) | <15 s expense capture, offline-first (FR-19), honest projections | `lib/features/transactions/*`, `lib/core/storage/*` | `docs/offline_strategy.md` |

## 2. Application of Theory and Literature (10)

| Sub-criterion | Evidence |
|---|---|
| Literature review depth (3) | `docs/academic_report_draft.md` §3 (context-aware computing, PFM research, TAM, nudge theory) |
| Academic/industry sources (2) | `docs/harvard_references.md` (all verifiable) |
| Critical comparison of existing systems (3) | Report §3.3 comparison: Mint (discontinued 2024), YNAB, Emma, Cleo, Money Manager |
| Theory → design decisions (2) | Report §4 links nudge theory→notifications, cognitive-load→dashboard, Fogg model→streaks |

## 3. Technical Implementation (20)

| Sub-criterion | Feature | Source files | Test evidence |
|---|---|---|---|
| Core functionality works (6) | FR-01..FR-11 | `lib/features/*` | `test/*`, `docs/verification_report.md` (honest status) |
| Suitable technologies (4) | Flutter, Riverpod, GoRouter, Firebase, ML Kit, Hive | `pubspec.yaml` | `docs/dependency_decisions.md` |
| Backend/API/DB integration (4) | Firestore repos, Storage, FCM, Remote Config, AI Logic | `lib/features/*/data/*`, `lib/core/*` | `firestore.rules`, `rules_test/` |
| Code quality/structure (3) | Clean Architecture, feature-first, MVVM | `lib/` layout | `analysis_options.yaml`, `docs/architecture.md` |
| Advanced features (3) | Camera OCR, mic voice entry, biometrics, offline sync, push, gen-AI | see FR-02/05/06/13/18/19 | RTM rows above |

## 4. UI/UX Design (10)

| Sub-criterion | Evidence |
|---|---|
| Visual design (3) | Design tokens `lib/app/theme/tokens.dart`, dark/light themes, brand `assets/brand/` |
| Navigation & flow (3) | GoRouter tree `lib/app/routing/router.dart`; 5-tab shell (Home/Transactions/AI/Plans/Profile) |
| Consistency & responsiveness (2) | Shared components `lib/core/widgets/`; adaptive layouts |
| Accessibility (2) | Semantics wrappers, chart text alternatives, 48dp targets, reduced motion; `test/widget/accessibility_test.dart` |

## 5. System Architecture (10)

| Sub-criterion | Evidence |
|---|---|
| Diagrams (3) | `docs/architecture.md` (Mermaid: context, container, feature deps, auth/OCR/AI/offline/notification flows, security boundaries) |
| Modular design (3) | `lib/features/<feature>/{domain,data,presentation}` |
| Frontend/backend separation (2) | Repository interfaces in domain; Firebase impls in data |
| Scalability planning (2) | Pagination, indexes (`firestore.indexes.json`), Remote Config, report §7 |

## 6. Security, Performance and Scalability (10)

| Sub-criterion | Evidence |
|---|---|
| Authentication/authorization (3) | FR-01/02; `firestore.rules` ownership tests; reauth for deletion |
| Data privacy/secure storage (2) | `flutter_secure_storage`, consent toggles, AI data minimisation; `docs/privacy_data_flow.md`, `docs/threat_model.md` |
| Performance optimisation (3) | `docs/performance_budgets.md` (targets marked as targets), pagination, image compression, provider scoping |
| Scalability (2) | Firestore model + indexes; stateless repos; report §7 |

## 7. Testing and Evaluation (10)

| Sub-criterion | Evidence |
|---|---|
| Functional testing (3) | `test/domain/*` (health score, forecast, duplicates, subscriptions, categoriser, OCR parser), repo + provider tests |
| UI/usability testing (2) | `test/widget/*`; `docs/evaluation_plan.md` (real-user study marked PERSONAL EVIDENCE REQUIRED) |
| Performance/security testing (2) | `rules_test/*`; performance plan in `docs/performance_budgets.md` |
| Results analysis (2) | `docs/test_results_summary.md`, `docs/verification_report.md` |
| Reflection (1) | Report §9 — PERSONAL EVIDENCE REQUIRED |

## 8. Report Quality (5) & 9. Referencing (5)

`docs/report_outline.md`, `docs/academic_report_draft.md` (3000-word structure, formal tone), `docs/harvard_references.md` (verified sources only, Harvard style).

## Learning-outcome coverage

| LO | Coverage |
|---|---|
| GUI principles | M3 design system, tokens, accessibility (RTM §4) |
| SDK proficiency: geolocation, mapping, multimedia, persistent storage | Multimedia (camera OCR, mic voice), persistent storage (Hive + secure storage + Firestore offline). Geolocation/mapping deliberately not collected — privacy-preserving context substitutes; justified in `docs/assumptions.md` A-07 and report §6. |
| Design patterns | Repository, MVVM, DI (Riverpod), Strategy (categoriser), Queue (offline ops) |
| Critical evaluation | Report §7–9, verification report |
| Advanced coding | Full codebase + tests |
