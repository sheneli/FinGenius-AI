# Rubric Evidence Map (100 marks)

Direct pointer from every marking sub-criterion to concrete artefacts.

## 1. Project Content & Innovation (20)
- Problem identification (5): report §1; `product_requirements.md` personas.
- Originality (5): layered explainable AI + transparent health score + honest forecasting — `insights/domain/*`, report §5; contrast vs Emma/Cleo opacity in §2.
- Smart functionality (5): OCR (`receipt_scanner/`), voice (`voice_entry_sheet.dart`), forecasts + backtest (`forecasting.dart`), duplicate/subscription detectors, Gemini assistant with validation (`ai_gateway.dart`, `ai_output_validator.dart`).
- User value (5): <15 s capture flows, offline-first (`offline_strategy.md`), payday/quiet-hours context.

## 2. Theory & Literature (10)
- Depth (3) + sources (2): report §2 with `harvard_references.md` (all verifiable).
- Comparison (3): §2 Mint/YNAB/Emma/Cleo gap analysis.
- Theory→design (2): Dey→context features; Thaler&Sunstein/Fogg→notifications; Davis→capture friction; Nielsen/WCAG→UI; Holt/Hyndman→forecasting.

## 3. Technical Implementation (20)
- Core functionality (6): 80 lib files across 16 features; journeys in `testing_guide.md`.
- Technologies (4): `pubspec.yaml` + `dependency_decisions.md`.
- Backend/DB (4): Firestore repos + queue (`owned_collection_repository.dart`, `pending_queue.dart`), Storage upload, Remote Config flags, FCM token lifecycle.
- Code quality (3): strict lints (`analysis_options.yaml`), typed `Result`/`Failure`, immutable entities, DI via Riverpod.
- Advanced (3): camera+ML Kit, mic+speech, biometrics, FLAG_SECURE channel (Kotlin), App Check, gen-AI via AI Logic.

## 4. UI/UX (10)
- Visual (3): tokens (`tokens.dart`), dark/light themes, original brand (`assets/brand/`, `logo_concepts.md`).
- Navigation (3): guarded GoRouter shell (`router.dart`).
- Consistency/responsiveness (2): shared widgets (`core/widgets/`), 420 dp form constraint, text-scale clamp.
- Accessibility (2): semantics on gauge/charts/tiles, table alternatives, 48 dp targets, `widgets_test.dart` semantics assertions.

## 5. Architecture (10)
- Diagrams (3): `architecture.md` (7 Mermaid diagrams).
- Modularity (3): feature-first Clean Architecture; dependency rules documented.
- Front/back separation (2): domain interfaces vs Firebase data layer.
- Scalability (2): indexes json, pagination, Remote Config levers, report §7.

## 6. Security, Performance & Scalability (10)
- AuthN/Z (3): auth flows + rules + 15 rules tests.
- Privacy/secure storage (2): `privacy_data_flow.md`, secure storage, consent gates, AI minimisation.
- Performance (3): `performance_budgets.md` (+ your measured actuals).
- Scalability (2): as §5 above.

## 7. Testing & Evaluation (10)
- Functional (3): 62 domain tests; journeys.
- UI/usability (2): widget tests + your SUS study (PERSONAL EVIDENCE REQUIRED).
- Perf/security testing (2): budgets method + rules tests + secret scan.
- Results analysis (2): `test_results_summary.md` + forecast backtest.
- Reflection (1): report §9 (yours).

## 8. Report Quality (5) & 9. Referencing (5)
- Structure: `report_outline.md` word budgets; formal draft prose in `academic_report_draft.md`.
- Referencing: Harvard list verified-only; in-text citations already embedded in the draft.
