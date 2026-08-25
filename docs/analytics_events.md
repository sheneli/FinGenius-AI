# Analytics Event Catalogue

Consent-gated (default OFF). Events never contain amounts, merchants, notes, emails or free text. Names are constants in `AnalyticsService` — nothing else may be logged.

| Event | Params | Purpose |
|---|---|---|
| fg_sign_up / fg_sign_in | — | activation funnel |
| fg_tx_add_manual / fg_tx_add_ocr / fg_tx_add_voice | — | capture-method mix |
| fg_ocr_scan_started / _succeeded / _failed | — | OCR success rate |
| fg_budget_created / fg_goal_created / fg_goal_contribution | — | planning adoption |
| fg_ai_question_asked | — | assistant engagement |
| fg_ai_fallback_served | reason(rate_limit\|offline\|invalid) | AI reliability |
| fg_subscription_confirmed / _dismissed | — | detector precision signal |
| fg_export_requested | format(json\|csv) | data-rights usage |
| fg_account_deleted | — | churn |
| fg_offline_tx_queued / fg_sync_completed | — | offline usage |

# Notification Strategy

Channels: one Android channel `fingenius_reminders` (default importance). Types: bill reminders (T-2 days + due day), budget alerts (80%/100% crossings), payday nudge ("payday tomorrow — review your plan"), weekly digest (local), AI monthly summary ready.

Rules: quiet hours enforced in `LocalNotificationsService.show` (default 22:00–07:30, user-set); consent toggle + Android 13 runtime permission both required; every push has an in-app copy in the notifications centre (`users/{uid}/notifications`); no shaming language; deep links to the relevant screen. FCM tokens stored per device under `users/{uid}/devices/{token}`, removed on logout. Server-initiated pushes require a backend/console campaign — v1 relies on local scheduling.
