# OpenRouter AI fallback

Gemini (via Firebase AI Logic) remains the primary provider. OpenRouter is a
secondary provider used **only after a Gemini request has already failed**.

## Request flow

```
ask() ──> Gemini ──success──> return Gemini result          (1 upstream call)
              │
            failure
              │
              ├─ no key configured ─> return the Gemini error
              │
              └─> OpenRouter (free model) ──success──> return result
                                    │
                                  failure
                                    └─> "Both AI services are unavailable…"
```

The providers are never called simultaneously or speculatively. A healthy
Gemini request costs exactly one upstream call — asserted by a test that fails
if OpenRouter is contacted on the success path.

### What triggers the fallback

Any Gemini failure: API error, timeout, rate limit / quota, disabled service,
5xx, and transport/network errors. Gemini keeps its own single retry for
transient errors first, so OpenRouter is reached only after that has failed too.

Two things happen *before* Gemini and so never reach the fallback: the
`ai_assistant_enabled` feature flag and the per-user daily quota. Output safety
validation happens *after*, and a reply that fails validation is not retried on
the other provider — the prompt is the problem, not the provider.

The daily quota is consumed once per **successful** answer regardless of which
provider served it, so a fallback never costs the user two requests, and a
double failure costs none.

## Free models only

The model is discovered at runtime from `GET /api/v1/models`, filtered to
entries whose prompt **and** completion prices both parse as zero, and cached
for 12 hours. Nothing is hard-coded, because OpenRouter's free tier changes
often and a pinned id becomes either a dead fallback or — worse — a paid model.

The filter fails closed: a missing, null or unparseable price counts as paid.
Among free models the largest context window wins, since the assistant prompt
carries a preamble plus aggregated figures.

Free models are heavily shared and frequently answer `429`, so up to two free
models are tried. A non-swappable error (auth, malformed request) stops
immediately rather than repeating the same failure.

## Supplying the API key

The key is **never** committed and never appears in source. Provide it at build
time:

```bash
cp dart_defines.example.json dart_defines.json   # git-ignored
# put your key in dart_defines.json, then:
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --release --split-per-abi --dart-define-from-file=dart_defines.json
```

With no key supplied the app builds and behaves exactly as before: the fallback
is inert and Gemini's own error is surfaced. There is no code path that requires
the key to exist.

`.gitignore` covers `dart_defines.json`, `dart_defines.*.json` and `.env*`.

### Honest limitation

`--dart-define` keeps the key out of Git, out of logs and out of crash reports.
It does **not** hide the key from someone holding the APK — dart-define values
are compiled into the binary and can be extracted. That is inherent to calling a
keyed API directly from a mobile client.

The real fix is to not ship the key at all: put a thin proxy in front of
OpenRouter (a Cloud Function, say) holding the key server-side and
authenticating callers with Firebase Auth + App Check. This is exactly what the
primary provider already does — Gemini goes through Firebase AI Logic, which is
why no Gemini key exists anywhere in this app. If you distribute a build with an
OpenRouter key embedded, treat that key as disposable: scope it narrowly, keep a
spend cap on it, and rotate it afterwards.

## Logging

Every request logs which provider answered (`request served by Gemini` /
`request served by OpenRouter (free tier)`) under the `AiGateway` name.
`OpenRouterException` carries only a short reason and an HTTP status — never a
response body, header or key — and everything logged additionally passes through
the gateway's sanitiser, which redacts `key=…` and `Bearer …` patterns.
