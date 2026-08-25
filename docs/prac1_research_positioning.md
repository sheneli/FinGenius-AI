# PRAC1 — Research Positioning & Literature Plan (for review)

FinGenius AI · CMP 7003 Emerging Mobile Applications · Draft for approval before Section 2 is written

---

## 1. Extracted brief requirements (authoritative)

**Formatting** — A4 · margins LHS/RHS 1 inch · binding margin 1/2 inch · header and footer 1 inch · font size 11 · Calibri or Aptos · Harvard referencing.

**Word limit** — 3,000 words. The brief states the count "will normally include any text, tables, calculations, figures, subtitles and citations. Reference lists and contents of appendices are excluded."

**Critical consequence:** the brief also states *"Contents of appendices are not usually considered when determining your final assessment grade."* Appendices therefore carry evidence, never argument. Every mark-bearing claim stays in the 3,000-word body.

**Submission** — PDF to Cardiff Met Moodle/Turnitin; Word format to ICBT SIS. Filename pattern `st########_CMP7003_PRAC1`. Coversheet and feedback sheet must be included. Do not copy the assignment question into the answer file.

**Rubric (100 marks)**

| # | Criterion | Marks | Sub-criteria |
|---|---|---|---|
| 1 | Project Content and Innovation | 20 | Problem identification & relevance 5 · Originality 5 · Smart functionality 5 · User value & practicality 5 |
| 2 | Application of Theory and Literature | 10 | Review depth 3 · Academic/industry sources 2 · Critical comparison of existing systems 3 · Theory applied to design 2 |
| 3 | Technical Implementation | 20 | Core functionality correct 6 · Suitable technologies 4 · Backend/API/database 4 · Code quality/structure 3 · Advanced features 3 |
| 4 | UI/UX Design | 10 | Visual quality 3 · Navigation & user flow 3 · Consistency & responsiveness 2 · Accessibility & usability 2 |
| 5 | System Architecture | 10 | Diagrams/models 3 · Modular design 3 · Frontend/backend separation 2 · Scalability/maintainability 2 |
| 6 | Security, Performance, Scalability | 10 | AuthN/AuthZ 3 · Data privacy & secure storage 2 · Performance optimisation 3 · Scalability planning 2 |
| 7 | Testing and Evaluation | 10 | Functional 3 · UI/usability 2 · Performance/security 2 · Results analysis 2 · Reflection 1 |
| 8 | Report Quality | 5 | Structure 2 · Academic writing 2 · Grammar/formatting 1 |
| 9 | Referencing | 5 | In-text 2 · Reference list accuracy 2 · Consistency 1 |

---

## 2. The positioning problem, stated honestly

The set topic is **"AI-Driven Smart Lifestyle Companion"** — an assistant for "daily routines, health, productivity, and environment" using "contextual inputs such as location and time".

FinGenius is a **financial-wellness** instantiation of that brief. That is a legitimate lifestyle domain, but the report must argue the mapping explicitly rather than assume it, because two brief expectations are not met literally:

- **No geolocation or mapping.** LO2 names "geolocation, mapping, multimedia, and persistent storage". FinGenius covers multimedia (camera + ML Kit OCR, microphone + speech-to-text, TTS) and persistent storage (Hive, `flutter_secure_storage`, Firestore) but ships no location permission at all.
- **Context is temporal, not spatial.** Adaptation comes from month windows, payday anchoring, bill horizons and spending history rather than place.

**Agreed approach:** defend the omission as a deliberate least-privilege decision and make it a security/privacy strength rather than hiding it. The report will state the trade-off in one sentence in Section 3 and evidence it in Section 5, using the manifest's permission set as proof.

---

## 3. Research gap (the spine of the report)

**Claim:** current intelligent personal-finance applications deliver automation without accountability. Four specific deficits, each of which FinGenius answers with implemented code.

| # | Gap in current systems | What FinGenius implements | Code evidence |
|---|---|---|---|
| G1 | Categorisation is opaque — users see a label, not a reason, and cannot correct the model | Four-layer categoriser returning `(categoryId, confidence, source)` where source is rule/learned/keyword/fallback; corrections feed layer 2 | `insights/domain/categorizer.dart` |
| G2 | Forecasts are presented as point estimates, hiding model error | Holt's linear exponential smoothing with an 80% band (1.28 sigma, sqrt(h) horizon scaling) plus a `backtest()` that reports predicted vs actual | `insights/domain/forecasting.dart` |
| G3 | Cloud AI is fed raw transaction-level data | Prompts carry only `FinancialAggregates` — totals, per-category sums, counts. No merchants, notes, account names or individual transactions | `ai_assistant/domain/financial_aggregates.dart` |
| G4 | LLM output in finance is emitted unchecked, and failure means the feature dies | Output validator rejects guaranteed-return and direct-trade patterns; structured replies are schema-validated; AI is only layer 4 behind three deterministic layers, with Gemini -> OpenRouter -> on-device fallback | `ai_assistant/domain/ai_output_validator.dart`, `data/ai_gateway.dart` |

Scoring composite is also transparent: `financial_health.dart` exposes five weighted factors with individual contributions, so the score can be explained rather than merely displayed.

**One-line gap statement for the report:**
> Intelligent personal-finance applications increasingly automate categorisation and prediction, but do so as opaque, cloud-dependent black boxes that neither expose the basis of their decisions nor communicate their own uncertainty — leaving users unable to judge when to trust them.

---

## 4. Literature themes -> rubric mapping

| Theme | Serves | Anchor status |
|---|---|---|
| T1 Mobile PFM & financial wellbeing | Crit 1 (problem relevance) | searching |
| T2 ML transaction categorisation | Crit 1, 3 | **verified** |
| T3 Cash-flow forecasting & uncertainty communication | Crit 1, 3, 7 | **verified** |
| T4 Explainable AI & trust in financial decision support | Crit 2 (theory->design) | **verified** |
| T5 LLM safety, hallucination, guardrails | Crit 1, 6 | searching |
| T6 Privacy-by-design, data minimisation, GDPR | Crit 6 | **verified** |
| T7 On-device vs cloud ML; OCR | Crit 3, 6 | searching |
| T8 Mobile UX & accessibility | Crit 4 | **verified** |
| T9 Offline-first architecture & sync | Crit 5 | searching |
| T10 Mobile security, OWASP MASVS, biometrics | Crit 6 | searching |
| T11 Automated mobile GUI testing | Crit 7 | **verified** |
| T12 Digital nudging & behaviour change | Crit 1 | **verified** |

---

## 5. Verified source register (10 of 35+ confirmed so far)

Every entry below was confirmed against Crossref metadata in this session. Nothing is cited from memory.

1. Kotios, D., Makridis, G., Fatouros, G. and Kyriazis, D. (2022) 'Deep learning enhancing banking services: a hybrid transaction classification and cash flow prediction approach', *Journal of Big Data*, 9(1), 100. doi:10.1186/s40537-022-00651-x — **T2/T3 keystone**: the closest prior system to FinGenius, combining categorisation and cash-flow prediction.
2. Leffrang, D. and Muller, O. (2025) 'Visualizing uncertainty in time series forecasts', *Journal of Forecasting*, 44(4), pp. 1235-1246. doi:10.1002/for.3222 — **T3 keystone**: direct empirical support for the forecast uncertainty band.
3. Hu, H., Wang, H., Dong, R., Chen, X. and Chen, C. (2024) 'Enhancing GUI exploration coverage of Android apps with deep link-integrated Monkey', *ACM TOSEM*, 33(6), pp. 1-31. doi:10.1145/3664810 — **T11**: explains the coverage ceiling of the Robo crawl, and why its own console suggested deep-link testing.
4. Di Martino, S., Fasolino, A.R., Starace, L.L.L. and Tramontana, P. (2024) 'GUI testing of Android applications', *Journal of Software: Evolution and Process*, 36(7), e2640. doi:10.1002/smr.2640 — **T11**: grounds the exploratory-vs-scripted testing argument.
5. Seixas Pereira, L., Matos, M. and Duarte, C. (2024) 'Exploring mobile device accessibility', *Proceedings of the CHI Conference on Human Factors in Computing Systems*, pp. 1-17. doi:10.1145/3613904.3642526 — **T8**.
6. Magoulas, G.S. and Polykalas, S.E. (2026) 'Mobile app privacy disclosures on Google Play in the post-GDPR context', *Information*, 17(4), 343. doi:10.3390/info17040343 — **T6**: permission-minimisation evidence supporting the no-location decision.
7. Hettler, F.M., Schumacher, J.-P., Anton, E., Eybey, B. and Teuteberg, F. (2025) 'Understanding the user perception of digital nudging in platform interface design', *Electronic Commerce Research*, 25(3), pp. 2097-2134. doi:10.1007/s10660-024-09825-6 — **T12**.
8. Kovari, A. (2024) 'AI for decision support: balancing accuracy, transparency, and trust across sectors', *Information*, 15(11), 725. doi:10.3390/info15110725 — **T4**.
9. Suri, B., Taneja, S., Bhanot, I., Sharma, H. and Raj, A. (2022) 'Cross-platform empirical analysis of mobile application development frameworks: Kotlin, React Native and Flutter', *Proceedings of ICIMMI 2022*, pp. 1-6. doi:10.1145/3590837.3590897 — **T7**: justifies the Flutter choice.
10. Yatawara, K., Sampath, T., Kalupahana, P.L., Rathnayake, S., Jayasuriya, N. and Rathnayake, N. (2025) 'A systematic review on consumer adoption of AI-driven chatbots', *Vision: The Journal of Business Perspective*. doi:10.1177/09722629251332349 — **T1/T5**.

Two date notes to resolve at reference QA: entries 2 and 7 carry an online-first year in Crossref that differs from the issue year; the issue year is used above, per Cite Them Right.

---

## 6. Outstanding blockers

| # | Needed | Why it matters | What I do on receipt |
|---|---|---|---|
| 1 | **Frequency Matrix reference image** | Section 8 of your instructions says not to guess the format. It is a graded artefact under Crit 2. | Build the matrix as a native Word table in the agreed structure, populated from the verified sources |
| 2 | **Name, Batch Number, Cardiff Met ID, ICBT ID, due date** | Required by the coversheet table in the brief, and by the `st########_CMP7003_PRAC1` filename | Populate the coversheet and name both output files |
| 3 | **PRES1 brief** (second document) | You referred to two; only PRAC1 arrived. Not blocking, but needed to keep the presentation consistent with the report | Cross-check for conflicting requirements |

---

## 7. Verified changes already made to the project

- `MainActivity.kt` and `secure_screen.dart` — FLAG_SECURE restored under a build-type gate (`ApplicationInfo.FLAG_DEBUGGABLE`), so release builds are protected and debug builds stay capturable. Originals in `.flagsecure_backup/`. **Needs `flutter analyze && flutter test` on your Mac.**
- No other project files have been modified.

## 8. Testing evidence correction (must not be overstated)

The Appium suite defines TC001-TC030. The JUnit XML from the 23 Aug 01:30-01:34 run covers six suites totalling **26 tests, 0 failures**. `04-receipt-scanning.spec.ts` (TC013-TC016) did not execute in that run, so the "100% pass rate" line in `test-summary.txt` describes 26 of 30 tests. The report will state 26 of 30 executed with receipt scanning declared as a coverage gap. Separately, `test-results.json` is hand-maintained rather than emitted by the runner; the XML is the citable artefact.

Firebase Test Lab Robo, verified from the console: **Passed** · Pixel 5, API 30 · 20 Aug 2026 · 6m 11s · crawl 5m 56s · 135 actions, 2 activities, 27 screens · all 135 actions successful.
