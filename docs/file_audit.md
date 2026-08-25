# File Audit — FinGenius AI (Phase 0)

Audit date: 2026-07-16. Every file in the workspace was inspected before implementation began.

## Inventory

| # | File | Classification | Purpose |
|---|------|----------------|---------|
| 1 | `CMP 7003_PRAC 01.docx` | Assessment material | Cardiff Met / ICBT CMP 7003 "Emerging Mobile Applications" PRAC1 brief (75% weighting, 3000-word report, Harvard referencing) for the "AI-Driven Smart Lifestyle Companion" case study, with full 100-mark rubric. |
| 2 | `google-services-3.json` | Firebase configuration | Android client configuration for Firebase project `fingenius-app-6dfcc`, storage bucket `fingenius-app-6dfcc.firebasestorage.app`, Android package `com.msc.fingenius`. |
| 3 | `.idea/` (6 files) | IDE metadata (ignorable) | Android Studio/IntelliJ metadata ("FinGenius App new"). No requirements. Excluded from build; not modified. |
| 4 | `.DS_Store` | OS metadata | macOS Finder artifact. Ignored. |

No existing source code, datasets, design assets, or branding files were found. The brand system and logo are therefore built from the approved specification in the project brief.

## Requirements extracted

From `CMP 7003_PRAC 01.docx`:

- Build a sophisticated mobile app (AI-Driven Smart Lifestyle Companion domain) that goes beyond CRUD: context-aware, adaptive, personalised recommendations, learning from behaviour.
- Emerging tech required: AI/ML, real-time data processing, cloud integration, modern mobile frameworks; recommendation systems / predictive analytics / NLP encouraged.
- User-centred UI adhering to UI/UX principles; responsive and accessible.
- Backend via APIs, cloud databases, real-time sync; modular, scalable, maintainable architecture; secure data handling.
- Systematic testing: functionality, usability, performance, security.
- Report: introduction, literature review, methodology, design & implementation, evaluation, conclusion; 3000 words; Harvard referencing; PDF; Calibri/Aptos 11pt; A4.
- Learning outcomes: GUI principles; platform SDK proficiency (geolocation, mapping, multimedia, persistent storage); design patterns; critical evaluation of performance/security/scalability; advanced coding proficiency.
- Rubric (100): Content & Innovation 20, Theory & Literature 10, Technical Implementation 20, UI/UX 10, Architecture 10, Security/Performance/Scalability 10, Testing & Evaluation 10, Report Quality 5, Referencing 5. Full sub-criteria captured in `docs/requirements_traceability_matrix.md`.

From `google-services-3.json` (values inspected, not reproduced here):

- `package_name` = `com.msc.fingenius` — **matches** the required Flutter Android application ID. ✅
- One Android API key present (Firebase client key — client-distributable by design, protected by App Check/rules; not a secret in the Gemini sense).
- `oauth_client` array is **empty** → Google Sign-In has **no** OAuth configuration. Consequence: Google Sign-In stays disabled behind a feature flag; email/password auth is the primary provider. Operator steps documented in `docs/setup/firebase_setup.md`.
- No indication of console-side enablement of FCM, App Check, AI Logic, or billing — these require documented operator actions and are treated as unverified until confirmed.

## Security concerns

1. `google-services-3.json` is Firebase *client* configuration. Not a server secret, but it should not be published gratuitously; real protection comes from Security Rules + App Check. It is copied to `android/app/google-services.json` (required by the Google Services Gradle plugin) and its values are never echoed in documentation or logs.
2. Empty OAuth client list means SHA-1/SHA-256 fingerprints were never registered — required later for Google Sign-In and Play Integrity/App Check.
3. No Gemini/server-side credentials exist anywhere in the workspace — correct; AI access goes through Firebase AI Logic, never a bundled API key.
4. `.idea/` may contain machine-specific paths; excluded via `.gitignore`.

## Conflicts and ambiguities

| Item | Resolution |
|------|-----------|
| Brief suggests geolocation/mapping as an LO; product spec mandates privacy-first, no gratuitous location collection | Location is NOT collected. Persistent storage, multimedia (camera/OCR/voice), and sensor use (camera, microphone, biometrics) satisfy the SDK-proficiency LO. Rationale: `docs/assumptions.md` A-07. |
| Brief is domain-agnostic ("lifestyle companion"); root spec fixes the financial-wellness domain | Financial wellness implemented as the lifestyle-companion instantiation; mapping argued in the report draft. |
| Filename `google-services-3.json` vs required `google-services.json` | Copied verbatim to `android/app/google-services.json`; original left untouched. |
| No branding guide file was actually attached despite reference to one | The approved fallback brand system from the specification (colours, Manrope, dark-first) is used as the source of truth. |

## How each file is used

- `CMP 7003_PRAC 01.docx` → drives `requirements_traceability_matrix.md`, `rubric_evidence_map.md`, `report_outline.md`, `academic_report_draft.md`.
- `google-services-3.json` → copied to `fingenius_ai/android/app/google-services.json`; package name validated against `applicationId` in `android/app/build.gradle.kts`.
- `.idea/`, `.DS_Store` → ignored.
