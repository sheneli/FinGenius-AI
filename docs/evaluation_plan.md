# Evaluation Plan

## Functional evaluation
Run the full automated suite (`flutter test`, rules tests) and the ten critical journeys (`docs/testing_guide.md`) on a real device + emulator suite. Record pass/fail per journey in `test_results_summary.md`.

## Usability evaluation — PERSONAL EVIDENCE REQUIRED
Recommended lightweight protocol (run it yourself; never invent participants):
- 3–5 participants, 20 minutes each, think-aloud.
- Tasks: (1) create account + first expense, (2) scan a real receipt and correct it, (3) create a budget and find whether you're over, (4) ask the assistant one question, (5) find and enable balance-hiding.
- Metrics: task completion, time-on-task, errors, SUS questionnaire (10 items), plus open feedback.
- Ethics: informed consent, no real financial data (provide seeded demo data), anonymised notes.

## Algorithmic evaluation (built-in, honest)
- Forecast: quote the in-app backtest (predicted vs actual per month) and the MAE the `Forecaster` reports. Requires ≥4 months of (seeded or real) data.
- Categoriser: run the seeded merchant list through `Categorizer` and report the confusion counts by layer (rule/learned/keyword/fallback).
- Duplicate/subscription detectors: report precision on a hand-labelled sample of your own seeded dataset.

## Performance evaluation
Follow the measurement methods in `performance_budgets.md`; report target vs actual per budget.

## Security evaluation
Rules-test results (15 cases), secret-scan output, permission review screenshot from Android settings, App Check enforcement screenshot.

# Test Results Summary

**Status: template — populate after executing the suites (no results are claimed that were not run).**

| Suite | Cases | Passed | Failed | Notes |
|---|---|---|---|---|
| Domain unit tests | 62 authored | _run me_ | | `flutter test test/domain` |
| Widget tests | 7 authored | _run me_ | | `flutter test test/widget` |
| Firestore rules | 10 authored | _run me_ | | `cd rules_test && npm test` |
| Storage rules | 5 authored | _run me_ | | ditto |
| Critical journeys (manual) | 10 defined | _run me_ | | checklist in testing_guide |
| Static analysis | — | _run me_ | | `flutter analyze` |
| Static structural checks (this environment) | 3 | 3 | 0 | imports, bracket tokenizer, secret scan — see verification_report |

# Figures Index

| Fig | Content | Source |
|---|---|---|
| 1 | System context diagram | `docs/architecture.md` (Mermaid → export PNG) |
| 2 | Container/component diagram | ditto |
| 3 | Security boundaries | ditto |
| 4 | Offline sync flow | ditto |
| 5 | Firestore data model | `docs/firestore_data_model.md` |
| 6 | Brand system / logo rationale | `assets/brand/brand_preview.svg`, `docs/logo_concepts.md` |
| 7 | Health-score factor breakdown screenshot | capture from Reports screen |
| 8 | OCR review screen with confidence chips | capture from device |
| 9 | Forecast chart with uncertainty band + backtest | capture from Reports |
| 10 | Offline pending-sync badge | capture in airplane mode |
Render Mermaid via mermaid.live or `mmdc` CLI for the PDF.
