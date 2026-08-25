# Dependency Decisions

**Environment caveat (honest):** this build environment had no access to pub.dev (network allowlist), so the version constraints below are the latest known-good stable majors and could not be re-verified at implementation time. Before first build run `flutter pub upgrade --major-versions` and re-run the analyzer. No abandoned or overlapping packages were selected; each entry is null-safe and Android-compatible.

| Package | Constraint | Why chosen / alternatives rejected |
|---|---|---|
| flutter_riverpod | ^2.6.1 | Mandated. Compile-safe DI + state; no codegen variant used to keep the build simple. |
| go_router | ^14.6.0 | Mandated. Declarative shell-route bottom nav, deep links, guards. |
| firebase_core / auth / cloud_firestore / firebase_storage / firebase_messaging / firebase_analytics / firebase_crashlytics / firebase_remote_config / firebase_app_check | ^3.x / ^5.x / ^5.x / ^12.x / ^15.x / ^11.x / ^4.x / ^5.x / ^0.3.x | Official FlutterFire set; versions form a mutually compatible BoM generation. |
| firebase_ai | ^2.0.0 | Firebase AI Logic SDK — Gemini without shipping an API key (auth + App Check attested). Replaces deprecated google_generative_ai for client apps. |
| google_mlkit_text_recognition | ^0.14.0 | ML Kit Text Recognition v2, on-device (Latin). Privacy: OCR before any cloud call. |
| hive_ce + hive_ce_flutter | ^2.x | Maintained community fork of Hive. Document-shaped cache + queue fits Firestore mirroring; Drift/sqflite rejected (SQL adds ceremony without relational need). |
| flutter_secure_storage | ^9.2.2 | Keystore-backed storage for biometric flag, session salt. |
| local_auth | ^2.3.0 | Biometric unlock (BiometricPrompt). |
| connectivity_plus | ^6.1.0 | Connectivity awareness for sync worker. |
| image_picker | ^1.1.2 | Camera/gallery for receipts and avatar. |
| flutter_image_compress | ^2.3.0 | Compress receipts before upload (budget: ≤ 500 KB). |
| fl_chart | ^0.69.0 | Charts; mature, pure-Flutter. syncfusion rejected (licence), charts_flutter rejected (discontinued). |
| flutter_svg | ^2.0.10 | Renders the vector brand mark in-app (splash/auth/about) — single source of truth with `assets/brand/`. |
| flutter_local_notifications | ^18.0.1 | Bill reminders/nudges with quiet-hours scheduling. |
| speech_to_text | ^7.0.0 | On-device platform speech recognition for voice expense. |
| google_fonts | ^6.2.1 | Manrope (OFL 1.1) without committing binaries; offline bundling documented. |
| intl | ^0.19.0 | Currency/date formatting. |
| uuid | ^4.5.1 | Client ids for idempotent offline ops. |
| crypto | ^3.0.6 | Receipt fingerprints (sha256). |
| path_provider | ^2.1.5 | Temp receipt files. |
| share_plus | ^10.1.2 | Data export sharing. |
| csv | ^6.0.0 | CSV export. |
| collection | ^1.18.0 | groupBy etc. |
| **dev** flutter_lints | ^5.0.0 | Official lint set + extra rules in analysis_options. |
| **dev** mocktail | ^1.0.4 | Mocks without codegen. |
| **dev** fake_cloud_firestore | ^3.1.0 | Repository tests without emulator. |
| **dev** firebase_auth_mocks | ^0.14.1 | Auth provider tests. |

Rejected: `get_it` (Riverpod covers DI), `bloc` (one state solution only), `rxdart` (streams suffice), `pdf` (report is external), `google_sign_in` (deferred until OAuth exists — would be dead weight; documented flag path instead).
