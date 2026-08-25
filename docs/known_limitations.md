# Known Limitations & Roadmap

## Honest limitations (v1)

1. **Unexecuted Flutter toolchain**: authored without Flutter/pub.dev access; analyzer/tests/builds must be run per README before any pass/fail claim. Version pins may need `pub upgrade` fixes.
2. **Delete-recreate race offline**: a queued edit can resurrect a doc deleted on another device (tombstones planned). `docs/offline_strategy.md`.
3. **Account deletion subtree**: app deletes auth user + root doc; full subcollection purge requires the Delete User Data extension (operator step).
4. **Budget alert flags** (`alert80Sent`) are modelled but push-triggered alerts need a server component; in-app banners work.
5. **AI conversations are session-local in the UI** (persistence schema exists; wiring the history list is v1.1).
6. **Categoriser learning** persists via the feedback collection but the learned map loads at startup only.
7. **Single-currency accounts assumed per user**; multi-currency conversion is out of scope.
8. **Voice parsing** handles simple English utterances only.
9. **OCR** tuned for Latin-script, single-column receipts; complex layouts degrade to manual entry (by design).
10. **No golden tests** committed — pixel baselines must be generated on a real toolchain first (committing unverified goldens would fake evidence).
11. **Health-score month window** uses current calendar month; users paid mid-month may prefer payday-anchored periods (roadmap).
12. **Charts x-axis labels** omitted on small charts for clarity; table alternative compensates.

## Roadmap
v1.1: tombstoned deletes, AI history UI, payday-anchored periods, golden tests, widget-test coverage for every screen. v1.2: home-screen widgets, CSV import, category budgets rollover, Wear OS glance. v2: household sharing, open-banking aggregation (region-dependent), on-device categoriser model trained on opt-in anonymised corrections (only when a real dataset + evaluation pipeline exists).
