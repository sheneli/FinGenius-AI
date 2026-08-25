# PRAC1 — Sections 5, 6 and 7, first draft for review

D. Sheneli Behehsha Munasinghe · Batch 28 · Cardiff Met st20357356 · ICBT CL/MSCIT/28/03

---

## 5. Security, Performance and Scalability  [282 words]

Authentication uses Firebase Authentication with email verification, and re-authentication is required before account deletion. Authorisation is enforced server-side rather than in the client: Firestore and Storage rules are default-deny, scope every path to `users/{uid}`, and validate types, ranges, string lengths and enumerated values before a write is accepted. Fifteen emulator tests exercise these rules, including cross-account access attempts. App Check with Play Integrity attests client authenticity, sensitive local values use Android encrypted storage, and screenshot protection applies to balance screens in release builds while remaining off in debug so capture tooling can operate. No third-party model key exists in the binary.

Three weaknesses are real and worth naming. Release builds are currently signed with the debug keystore, which is acceptable for assessment but not for distribution. R8 minification is disabled because enabling it crashed the image cropper on every profile-photo upload, so the shipped code carries no obfuscation — a working build was preferred to a smaller one that broke a core feature. The biometric lock gates the interface rather than releasing a cryptographic key, which is precisely the pattern Zhang et al. (2025) identify as widespread misuse of Android fingerprint APIs.

Performance figures here are budgets rather than measurements, and no profiling run has been conducted. Optimisations are nonetheless implemented and inspectable: Firestore queries are bounded at 500 with supporting indexes, dashboard sections watch individual providers so rebuilds stay scoped, and images are compressed before upload.

Scalability follows from the data model. Per-user subcollections shard naturally by identifier, and the Cloudflare Worker is stateless edge compute with optional per-user rate limiting in KV. Cost, not throughput, is the binding constraint, which is why generative calls are quota-limited on both client and proxy.

---

## 6. Testing, Evaluation and Critical Reflection  [312 words]

Firebase Test Lab executed a Robo crawl on a Pixel 5 running API level 30. The run passed, lasting 6 minutes 11 seconds, performing 135 actions across 2 activities and reaching 27 distinct screens with every action completing successfully and no crashes or ANRs recorded *(Appendix E)*. That result should be read for what it demonstrates. Robo is an automated crawler, and Hu et al. (2024) document the coverage ceiling of Monkey-style exploration, noting that undirected crawling misses states reachable only through specific entry points — the reason the console itself suggested deep-link testing. The crawl evidences stability under exploratory input, not functional correctness.

Functional correctness was addressed separately with Appium and WebdriverIO against a physical Samsung SM-A127F on Android 13. The JUnit output records 26 tests across six suites with zero failures. The suite defines thirty cases, so four remain unexecuted: the receipt-scanning tests, TC013 to TC016, did not run in the final pass. Reporting this as a hundred per cent pass rate would misstate coverage; receipt scanning is the application's most technically distinctive feature and is currently its largest verification gap. Di Martino et al. (2024) note that exploratory and scripted strategies detect different defect classes, which is why both were used.

Below the interface, 262 unit and widget test cases across 31 files cover the domain logic. Their execution status is unverified: the CI workflow invokes `flutter analyze` and `flutter test` with failures suppressed, so a green pipeline does not evidence passing tests. No usability, accessibility, performance-profiling or security testing has been performed.

One development failure is instructive. The fallback proxy ranked free models by context length, placing two Google Lyria music-generation models first. Both failed every chat request, the proxy returned 502, and users saw an availability error while working chat models sat unused. The fix filters models to those declaring text-only output and fails closed on unrecognised metadata.

---

## 7. Conclusion and Future Enhancements  [145 words]

FinGenius AI implements an explainability-first response to a documented gap: intelligent finance applications automate categorisation and prediction without exposing their basis or their uncertainty. Categorisation returns provenance and confidence and learns from correction, forecasts publish intervals alongside a visible backtest, the health score decomposes into weighted factors, and generative output is validated inside the application rather than trusted from the provider. Firebase Test Lab and Appium evidence stability and functional correctness within the coverage stated.

Future work follows from the limitations above rather than from novelty. Closing the receipt-scanning test gap and enforcing test failures in CI are immediate. Binding the biometric lock to a keystore-backed key would address the weakness Zhang et al. (2025) describe. Re-enabling minification requires resolving the cropper crash on-device. Beyond that, migrating categorisation to a small on-device model would extend the privacy position that Heydari and Mahmoud (2025) argue for.

---

## Word budget — measured, trims applied

First draft was 3,032, i.e. 32 over the limit. Cut in place; no citation or rubric-relevant claim lost.

| Section | Words |
|---|---|
| 1 Introduction | 248 |
| 2 Literature Review | 804 |
| 3 Methodology | 342 |
| 4 Design & Implementation | 850 |
| 5 Security/Performance/Scalability | 282 |
| 6 Testing & Evaluation | 312 |
| 7 Conclusion | 145 |
| ASSESSED BODY | 2,983 |

One trim outstanding: Section 2.5, ~30 words, landing the body near 2,953 — inside the 2,850-2,950 target with margin for figure captions once the Word document is built.

## Where claims were deliberately weakened to keep them true

1. Performance is stated as budgets, not results. docs/performance_budgets.md says so in its own first line. An assessor opening that file finds "TARGETS, not measured results" in bold. Section 5 earns its marks on inspectable optimisations instead.
2. Test execution status is declared unverified. CI runs `flutter test || true`. A passing pipeline proves the APK built, not that 262 tests pass. IF YOU HAVE RUN `flutter test` LOCALLY AND IT PASSED, SAY SO — it will be stated as evidence with the date and materially strengthens Criterion 7.
3. Three security weaknesses are volunteered: debug-keystore release signing, R8 disabled, biometric lock gating UI rather than releasing a key. Naming the third against Zhang et al. (2025) turns an implementation weakness into evidence of critical judgement, worth more under Criterion 6 than an unqualified security claim.

## Outstanding from you
- Frequency Matrix reference image
- Submission due date for the coversheet
