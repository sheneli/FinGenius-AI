# FinGenius AI — Product Requirements

**Intelligent Personal Finance Management and Financial Wellness Companion** — the financial-wellness instantiation of CMP 7003's "AI-Driven Smart Lifestyle Companion". Financial behaviour is a lifestyle driver: money stress shapes routines, sleep, productivity, and goals. FinGenius AI observes financial behaviour, adapts to it, and nudges users towards healthier habits.

## Personas

**P1 — Sasha, 27, junior analyst (primary).** Salaried, pays rent, subscriptions creep, saves irregularly. Wants effortless expense capture (receipt scan, voice), a truthful picture of where money goes, and payday-aware guidance.

**P2 — Nuwan, 41, freelancer.** Irregular income, multiple accounts. Needs cash-flow forecasting, bill reminders, and offline entry (client sites with poor connectivity).

**P3 — Amara, 33, budgeter with a goal.** Saving for a house deposit. Needs goals with projections, budget-vs-actual truth, and motivating — never shaming — feedback.

## Primary journeys

1. Register → verify email → onboard (consent, currency, first account) → dashboard.
2. Capture an expense in <15 s via receipt scan or voice, correct AI-extracted fields, save.
3. Set a monthly budget → get payday-aware nudges → review budget-vs-actual.
4. Create a savings goal → contribute → see an honest projection with uncertainty.
5. Ask the AI assistant "why was March expensive?" → grounded, safe, aggregated-data answer.
6. Go offline → add transactions → auto-sync with visible pending state.
7. Export all data / delete account with reauthentication.

## Functional requirements (FR)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | Email/password sign-up, sign-in, verification, password reset, reauth for destructive actions | Must |
| FR-02 | Biometric app lock (opt-in) | Must |
| FR-03 | CRUD accounts (cash, bank, card, mobile wallet, savings) with balances | Must |
| FR-04 | CRUD income/expense transactions with categories, notes, receipts | Must |
| FR-05 | Receipt scan → ML Kit OCR → parsed fields with confidence → user correction → save | Must |
| FR-06 | Voice expense entry with confirmation before save | Should |
| FR-07 | Monthly budgets per category with progress, alerts at 80%/100% | Must |
| FR-08 | Savings goals with contributions and explainable projections | Must |
| FR-09 | Dashboard: greeting, net worth, income/expense/savings, health score, cash-flow chart, spending breakdown, budgets, goals, recent transactions, upcoming bills, subscriptions, AI insights, alerts; balances hideable | Must |
| FR-10 | Reports: line/area/bar/donut charts, budget-vs-actual, trends, text alternatives | Must |
| FR-11 | Calendar of recurring bills; mark paid; reminders | Must |
| FR-12 | Subscription detection from recurring patterns, user confirm/dismiss | Must |
| FR-13 | AI assistant (Gemini via Firebase AI Logic): Q&A over aggregated data, monthly summary, insights | Must |
| FR-14 | AI/heuristic expense categorisation with confidence + user correction learning | Must |
| FR-15 | Duplicate-transaction detection | Must |
| FR-16 | Financial-health score 0–100 with visible factor breakdown | Must |
| FR-17 | Cash-flow forecast (explainable baseline + uncertainty band) | Must |
| FR-18 | Notification centre; quiet hours; payday-aware and behaviour-based nudges | Must |
| FR-19 | Offline create/read of transactions with pending queue + sync indicators | Must |
| FR-20 | Data export (JSON + CSV) | Must |
| FR-21 | Account deletion (reauth, cloud + local wipe) | Must |
| FR-22 | Preferences: theme (dark default/light), currency, hide balances, consent toggles (analytics, AI) | Must |
| FR-23 | Onboarding with disclaimers and consent | Must |
| FR-24 | Google Sign-In — implemented but feature-flagged OFF until OAuth is configured | Won't-fake |

## Non-functional requirements (NFR)

| ID | Requirement |
|----|-------------|
| NFR-01 | Cold start to first frame < 2 s on mid-range hardware (target) |
| NFR-02 | 60 fps scrolling on transaction list with 1k+ items (paginated) |
| NFR-03 | WCAG 2.1 AA-aligned: contrast, touch targets ≥ 48dp, TalkBack semantics, text scaling to 200%, reduced motion |
| NFR-04 | All network via HTTPS; Firestore/Storage access gated by ownership rules + App Check |
| NFR-05 | No sensitive values in logs; secure local storage for tokens/flags |
| NFR-06 | AI requests rate-limited per user; prompts minimised/aggregated |
| NFR-07 | Offline reads of recent data always available after first sync |
| NFR-08 | All money maths in integer minor units; typed errors, no silent failure |
| NFR-09 | Feature flags for anything requiring unconfigured console services |

## Acceptance criteria (samples, full set mirrored in RTM)

- AC-05a: A legible receipt photo produces merchant, date, total candidates with confidence chips; every field editable before save; failure path still allows manual entry.
- AC-16a: Health score screen lists each factor, its weight, its current contribution, and one actionable improvement hint.
- AC-19a: Airplane-mode transaction shows "pending sync" badge; reconnecting syncs and clears badge without duplicates.
- AC-13a: AI answers include a disclaimer, never name specific securities to buy, and degrade gracefully (cached insight or apology) when offline/rate-limited.

## Out of scope (v1)

Bank aggregation/open banking, payments/transfers, multi-user households, iOS/web, investment tracking, custom-trained ML models (no real dataset exists — honesty rule), location-based features.
