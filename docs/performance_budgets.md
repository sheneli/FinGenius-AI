# Performance Budgets

**Status: TARGETS, not measured results.** This environment cannot run the app; nothing below is claimed as achieved. Measure with the listed method on a mid-range device (e.g. Pixel 6a / Galaxy A54) and record actuals in `docs/test_results_summary.md`.

| Area | Budget (target) | How to measure |
|---|---|---|
| Cold start → first frame | < 2.0 s | `adb shell am start -W com.msc.fingenius/.MainActivity` (TotalTime) |
| Dashboard first render (100 tx) | < 700 ms after data | DevTools timeline |
| Transaction list scroll (1k rows) | 60 fps, no jank > 32 ms | DevTools performance overlay |
| Receipt OCR (ML Kit, 2048px) | < 2.5 s on-device | stopwatch around `recognizeLines` |
| Receipt upload (compressed) | ≤ 500 KB payload, < 4 s on 4G | Storage metadata + network profiler |
| AI first token/response | < 8 s p90 (timeout 30 s) | gateway logs |
| App size (release AAB) | < 40 MB | `flutter build appbundle --analyze-size` |
| Memory steady-state | < 300 MB | Android Studio profiler |

## Optimisations implemented in code
Firestore query limits (500) + indexes; provider-scoped rebuilds (each dashboard section watches only its provider); `ListView.builder` everywhere; image compression before upload; charts capped to bounded datasets; static skeletons (reduced-motion friendly); Hive mirror avoids re-reads on cold start; lazy feature init via GoRouter branches; controllers/streams disposed (`cancel_subscriptions`, `close_sinks` lints on).
