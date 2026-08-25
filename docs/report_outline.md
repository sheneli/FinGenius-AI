# Report Outline — CMP 7003 PRAC1 (3000 words, Harvard, PDF, Calibri/Aptos 11)

Suggested word budget (≈2950 + figures):

1. **Introduction & Problem Domain** (~280) — financial stress as a lifestyle problem; FinGenius AI as the financial-wellness instantiation of the Smart Lifestyle Companion; aims and objectives.
2. **Literature Review** (~430) — context-aware computing (Dey); PFM research (Kaye et al.); financial-literacy interventions (Fernandes et al.); nudge theory (Thaler & Sunstein); TAM (Davis); comparison of Mint (discontinued), YNAB, Emma, Cleo; the gap: transparent, privacy-first, explainable AI guidance.
3. **Methodology** (~300) — iterative vertical-slice development; requirements → RTM; technology justification (Flutter, Firebase, ML Kit, Gemini via AI Logic); ethics of AI use.
4. **System Architecture** (~330) — Clean Architecture/MVVM/Repository; Firestore model; offline queue; security boundaries. Figures 1–4.
5. **Design & Implementation** (~520) — design tokens & dark-first M3 UI; navigation; layered AI (rules→learned→keyword→Gemini); health-score formula; forecasting with uncertainty; OCR pipeline; voice entry. Figures 5–8.
6. **Security & Privacy** (~280) — STRIDE summary; rules + App Check; data minimisation to AI; consent model.
7. **Performance & Scalability** (~200) — budgets vs measured results (insert actuals); pagination/indexes; Remote Config levers.
8. **Testing & Evaluation** (~380) — test pyramid + rules tests; results table (insert actuals); usability evaluation (PERSONAL EVIDENCE REQUIRED); forecast backtest as self-evaluation.
9. **Challenges & Critical Reflection** (~130) — PERSONAL EVIDENCE REQUIRED.
10. **Conclusion & Future Enhancements** (~100) — tombstoned sync, on-device model (only with a real dataset), edge/XR outlook.

References (excluded from count) — `harvard_references.md`. Appendices: RTM, extra screenshots, test logs.
