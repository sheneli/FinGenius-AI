# FinGenius AI — Architecture

Clean Architecture + feature-first + MVVM. Domain layers are pure Dart (testable without Flutter). Data layers implement domain repository interfaces against Firebase/Hive. Presentation uses Riverpod `Notifier`s as ViewModels.

## System context

```mermaid
flowchart LR
  U[User] --> APP[FinGenius AI\nFlutter Android]
  APP --> AUTH[Firebase Auth]
  APP --> FS[(Cloud Firestore)]
  APP --> ST[(Firebase Storage)]
  APP --> RC[Remote Config]
  APP --> AN[Analytics + Crashlytics]
  APP --> FCM[Cloud Messaging]
  APP --> AI[Firebase AI Logic → Gemini]
  APP --> MLK[ML Kit Text Recognition v2\non-device]
  APP --> HIVE[(Hive local cache\n+ pending queue)]
  APP --> SEC[Android Keystore /\nEncryptedSharedPreferences]
  AC[App Check / Play Integrity] -. attests .-> AUTH & FS & ST & AI
```

## Container / component view

```mermaid
flowchart TB
  subgraph Presentation
    UI[Screens + Widgets] --> VM[Riverpod Notifiers / ViewModels]
  end
  subgraph Domain
    VM --> UC[Use-cases & domain services\nhealth score, forecast, duplicates,\nsubscriptions, categoriser, OCR parser]
    UC --> RI[Repository interfaces]
    ENT[Entities: Money, Transaction, Account,\nBudget, Goal, Bill, Receipt, Insight]
  end
  subgraph Data
    RI --> RIMPL[Repository implementations]
    RIMPL --> FSD[Firestore DataSource]
    RIMPL --> LCD[Hive local cache]
    RIMPL --> Q[Pending-op queue]
    RIMPL --> STD[Storage DataSource]
    RIMPL --> AID[AI service (Firebase AI Logic)]
  end
```

## Feature dependency rules

```mermaid
flowchart LR
  auth --> core
  transactions --> core & accounts
  dashboard --> transactions & budgets & goals & insights & bills
  budgets --> transactions
  goals --> core
  receipt_scanner --> transactions
  ai_assistant --> insights & transactions
  insights --> transactions & budgets & goals & bills
  reports --> transactions & budgets
  bills --> transactions
  notifications --> core
  profile --> auth & core
```
Features never import other features' data layers — only domain entities/providers. `core` imports nothing from features.

## Authentication flow

```mermaid
sequenceDiagram
  participant U as User
  participant A as App
  participant FA as Firebase Auth
  U->>A: Sign up (email, password)
  A->>FA: createUser
  FA-->>A: user (unverified)
  A->>FA: sendEmailVerification
  A-->>U: Verify-email screen (poll/resend)
  U->>A: Sign in after verify
  A->>FA: signIn → ID token
  A->>A: create user doc if absent, start sync
  Note over A: Biometric gate (local) wraps app resume if enabled
```

## Receipt OCR flow

```mermaid
sequenceDiagram
  participant U as User
  participant C as Camera/Gallery
  participant M as ML Kit (on-device)
  participant P as ReceiptParser (pure Dart)
  participant AI as Gemini (optional, minimised)
  U->>C: capture/pick image
  C->>M: recognizeText(image)
  M-->>P: raw text blocks
  P-->>U: merchant/date/total/tax candidates + confidence
  opt low confidence & user consented to AI
    P->>AI: redacted text lines only
    AI-->>P: normalised fields (validated JSON)
  end
  U->>U: review & correct every field
  U->>A: save → duplicate check → transaction + receipt upload → temp files deleted
```

## AI request flow

```mermaid
sequenceDiagram
  participant VM as ViewModel
  participant G as AiGateway
  participant RC as Remote Config
  participant L as RateLimiter (per-user, local+rules)
  participant FAI as Firebase AI Logic
  VM->>G: ask(question, aggregates)
  G->>RC: model id, max tokens, enabled?
  G->>L: acquire() — deny if exhausted
  G->>G: build minimised prompt (aggregates, never raw history)
  G->>FAI: generateContent (App Check attested)
  FAI-->>G: candidate
  G->>G: validate structure + safety + disclaimer
  G-->>VM: InsightResult | typed failure (fallback: cached/local heuristic)
```

## Offline synchronisation

```mermaid
flowchart LR
  W[Write op] --> QU[Hive pending queue\nop id = uuid, idempotent]
  QU -->|online| FS[(Firestore)]
  FS -->|snapshot listeners| CACHE[Hive read cache]
  CACHE --> UI
  CONN[connectivity_plus] -->|regained| SYNC[Sync worker\nexponential backoff]
  SYNC --> QU
  FS -. serverTimestamp wins, deletes win .-> CONFLICT[Conflict resolver]
```

## Notification flow

FCM token registered post-consent → stored at `users/{uid}/devices/{token}`. Local scheduled notifications for bill reminders/nudges respect quiet hours (default 22:00–07:30, user-configurable). Notification centre persists in-app notifications at `users/{uid}/notifications`.

## Firestore data model (summary — full schema in `docs/firestore_data_model.md`)

```
users/{uid}                        profile, prefs, consent, schemaVersion
  accounts/{id}                    name, type, balanceMinor, currency
  transactions/{id}                type, amountMinor, categoryId, date, accountId, receiptId?, pending flags
  categories/{id}                  seeded + custom, icon, colorKey
  budgets/{id}                     categoryId, periodKey(YYYY-MM), limitMinor
  goals/{id}                       target, deadline, contributions[]
  bills/{id}                       recurrence rule, nextDue, autoDetected?
  subscriptions/{id}               merchant, interval, confidence, status
  notifications/{id}               type, title, body, read
  receipts/{id}                    storagePath, ocr fields, confidence
  ai_conversations/{id}/messages   role, content, createdAt
  insights/{id}                    type, payload, period
  reports/{YYYY-MM}                monthly AI summary + aggregates
  health_history/{YYYY-MM}         score + factor breakdown
  feedback/{id}                    categorisation corrections (learning source)
```

## Security boundaries

```mermaid
flowchart TB
  subgraph Device
    UIL[UI] --> DOM[Domain]
    DOM --> SECURE[Secure storage: session flags, biometric pref]
    DOM --> HIVEB[(Hive boxes — per-uid, cleared on logout)]
  end
  subgraph TrustBoundary1 [TLS + App Check]
    FSR[Firestore ← rules: request.auth.uid == uid path owner]
    STR[Storage ← rules: owner + MIME + ≤5MB]
    AIL[AI Logic ← auth + App Check + RC limits]
  end
  Device --> TrustBoundary1
```

## Key patterns

Repository (domain interface / Firebase impl), MVVM (Riverpod Notifier), Strategy (categorisation pipeline stages), Command queue (offline ops), Result type (`Result<T>` sealed) for typed errors, DI via Riverpod providers, immutable entities (freezed-style manual immutability without codegen).
