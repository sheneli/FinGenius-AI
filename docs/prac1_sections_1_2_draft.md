# PRAC1 — Sections 1 and 2, first draft for review

D. Sheneli Behehsha Munasinghe · Batch 28 · Cardiff Met st20357356 · ICBT CL/MSCIT/28/03

Every citation is drawn from the 52-source verified register (docs/prac1_verified_references.md). No source is cited that was not confirmed against Crossref.

---

## 1. Introduction and Problem Definition  [248 words]

Personal financial management remains a persistent difficulty rather than a solved problem, and mobile applications have become its dominant intervention. Carlin, Olafsson and Pagel (2023) provide causal field evidence that easier mobile access to account information measurably reduces costly financial mistakes, and Zhang and Fan (2024) trace the pathway by which mobile fintech use converts into financial wellbeing. That conversion is not automatic. Gafoor and Amilan (2024) find the effect is mediated by financial knowledge and behaviour, which implies an application that merely automates decisions may improve convenience while leaving capability untouched.

Existing applications lean heavily on automation. Commercial systems classify transactions and project balances using models the user cannot inspect, correct or calibrate; the production categoriser behind QuickBooks is a relational deep-learning model operating entirely server-side (Dong et al., 2025). The outcome is accuracy without accountability.

FinGenius AI responds to this as the financial-wellness instantiation of the Smart Lifestyle Companion brief. It is an Android application written in Flutter against Firebase services and targeted at Sri Lankan users, whose merchant landscape is largely absent from the Western corpora on which mainstream categorisers are trained.

Its contribution is architectural rather than algorithmic. Every intelligent output carries its own provenance, confidence and uncertainty, and the generative layer is deliberately constrained so the system degrades rather than fails. Sections 2 to 4 establish the research basis, development method and implementation. Sections 5 to 7 evaluate security, performance and testing, and reflect on what that evaluation does and does not demonstrate.

---

## 2. Literature Review and Research Gap  [765 words prose / 804 incl. subheadings]

### 2.1 Automated categorisation: accurate but opaque

Transaction categorisation underpins every downstream insight, and research has converged on supervised classification of short merchant descriptors. Minaee et al. (2021) survey the neural methods that displaced bag-of-words baselines for precisely this kind of noisy short text. Kotios et al. (2022) demonstrate the closest architectural precedent to the present system, pairing deep-learning transaction classification with cash-flow prediction inside one banking platform. Dong et al. (2025) supply the strongest production evidence, showing that relational deep learning over merchant and account context outperforms text-only classifiers at commercial scale.

A shared assumption runs through all three, and it is worth challenging. Each treats categorisation as a prediction problem to be maximised, and none reports how a user discovers why a label was assigned or corrects it durably. Kotios et al. (2022) evaluate on accuracy; Dong et al. (2025) on ranking quality. Neither measures comprehension or correction. A second limitation is geographic: models trained on Western corpora have no representation for merchants such as Keells, PickMe or CEB, so non-Western vocabularies collapse into a default category.

### 2.2 Forecasting and the honest reporting of error

Petropoulos et al. (2022) establish exponential smoothing as a competitive and still-current forecasting family, and Smyl et al. (2025) extend it with Bayesian variants that yield calibrated prediction intervals on short, noisy series — the exact regime of household cash flow. The M5 uncertainty competition demonstrated conclusively that probabilistic forecasts outperform point estimates when evaluated properly (Makridakis et al., 2022). Ibrain and Hernandez (2024) add that filtering recurring transactions such as salary, rent and subscriptions before forecasting materially improves accuracy on personal financial series.

Consumer applications have not followed. They typically present a single projected figure, which conceals model error at the moment the user is deciding whether to rely on it. Leffrang and Muller (2025) show experimentally that visualising forecast uncertainty changes user confidence and the degree to which algorithmic advice is taken up. The literature therefore supports interval reporting, while deployed products largely do not implement it.

### 2.3 Explainability, trust and the right to contest

Ioannou et al. (2026) establish that explanation quality determines acceptance specifically in financial AI, and de Lange et al. (2022) demonstrate post-hoc attribution working on tabular financial models. The more useful finding for design is subtler. Cetinkaya and Kramer (2025) separate transparency from trust empirically, showing the first does not automatically produce the second, while Dogru and Kramer (2025) reframe the objective as *appropriate reliance* — calibrated acceptance and correction, not maximal agreement. Starke et al. (2024) find across countries that users want mechanisms to contest algorithmic personalisation rather than merely to view it.

Read together these findings point somewhere more demanding than an explanation panel. Explanation is only meaningful when it is actionable, and an interface that displays reasoning without accepting correction satisfies transparency while failing reliance.

### 2.4 Generative AI in a financial setting

Pak (2026) documents that consumers already use generative AI for personal money management, which makes the safety question practical rather than hypothetical. Jalan et al. (2026) catalogue the guardrail landscape, and Khanvilkar and Shinde (2025) address hallucination specifically where generative systems issue financial guidance. The critical result is Luo et al. (2026), who demonstrate that provider-side safety guardrails can be bypassed by adversarial prompting. Zhang and Zhang (2025) reach a compatible conclusion from the retrieval direction, and Filabi, Duffy and Parrish (2026) set out the regulatory duties attaching to AI-mediated financial advice.

The implication is that delegating safety to the model vendor is insufficient. Validation must sit in the application, below the provider boundary.

### 2.5 The privacy cost of context

Magoulas and Polykalas (2026) analyse permission and disclosure practice across Google Play after GDPR and find over-collection remains routine, while Tunca (2024) reviews privacy-by-design as a regulatory expectation rather than an option. Heydari and Mahmoud (2025) survey on-device inference as the structural alternative to shipping raw data to the cloud, and Hu et al. (2024) set out the threat model that cloud inference introduces. Existing intelligent finance applications tend to resolve this tension in favour of capability, transmitting transaction-level records to obtain better inference.

### 2.6 The research gap

Four deficits recur across this literature and are not addressed together by any reviewed system. Categorisation is optimised for accuracy but not for comprehension or correction. Forecasts are published as point estimates despite evidence favouring intervals. Generative components rely on vendor-side guardrails shown to be bypassable. Context is purchased with raw personal data despite regulatory and technical alternatives.

Stated as one claim: **intelligent personal-finance applications increasingly automate categorisation and prediction, but do so as opaque, cloud-dependent systems that neither expose the basis of their decisions nor communicate their own uncertainty, leaving users unable to judge when to trust them.** FinGenius AI is designed against that gap, and Section 4 traces each of the four deficits to the component answering it.

---

## Frequency Matrix — PROVISIONAL FORMAT

Confirm against the reference image. This uses the conventional concept-matrix layout (sources as rows, recurring concepts as columns, frequency totals beneath). If the example differs, the content transfers unchanged into the required structure.

Condensed version for the report body. The full 52-source matrix goes to Appendix B, since the brief counts body tables toward the 3,000 words.

| Concept | Sources | What the concentration shows |
|---|---|---|
| C1 Automated categorisation | 4 | Well established; consistently evaluated on accuracy, never on user comprehension |
| C2 Cash-flow forecasting | 5 | Mature methods available; personal-finance application under-represented |
| C3 Uncertainty communication | 3 | Strong experimental support, near-absent from deployed consumer products |
| C4 Explainability / transparency | 6 | Dense and growing; converging on explanation quality, not mere presence |
| C5 Trust and contestability | 7 | Recent shift from "show the reasoning" to "allow correction" |
| C6 LLM safety and guardrails | 7 | Rapid 2025-26 growth; consensus that vendor-side guardrails are insufficient alone |
| C7 Privacy and data minimisation | 5 | Regulatory expectation established; implementation practice lags |
| C8 Mobile security and authentication | 6 | Mature; biometric API misuse a recurring empirical finding |
| C9 Usability and accessibility | 4 | Accessibility routinely neglected in shipped Android apps |
| C10 Testing and evaluation | 2 | Crawler-based testing has a documented coverage ceiling |

The gap this reveals: C1 and C2 are dense (mature technique), C4 and C5 are dense (mature theory), but almost no reviewed source occupies both regions simultaneously. The intersection of accurate automation and contestable explanation in a personal-finance context is where this project sits.

---

## Notes for review

1. Word counts are measured, not estimated. S1 = 248 (target 250). S2 = 765 prose / 804 incl. subheadings (target 700). Running total 1,052 of a planned 950; leaves 1,948 for Sections 3-7 against a 2,000 budget. Section 2.5 is the most compressible, roughly 60 words without losing a citation.
2. The Sri Lanka angle is doing real work for Criterion 1 (Originality, 5 marks). categorizer.dart contains Keells, Cargills, Arpico, PickMe, Dialog, Mobitel, SLT, CEB and Daraz. Mainstream categorisers cannot resolve these merchants.
3. Section 2.3 is the pivot. Dogru and Kramer's "appropriate reliance" plus Starke et al.'s contestability finding elevate the correction loop from a feature to a theoretically motivated design decision. This is where Criterion 2's "theory applied to design decisions" (2 marks) is earned.
4. Nothing here is claimed that the code does not do. Every forward reference in 2.6 maps to a file that has been read.
