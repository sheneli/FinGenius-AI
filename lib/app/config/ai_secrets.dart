/// Build-time configuration for the fallback AI provider.
///
/// The key is injected at compile time and never written into source:
///
///   flutter build apk --release --dart-define-from-file=dart_defines.json
///
/// `dart_defines.json` is git-ignored; `dart_defines.example.json` shows the
/// shape. With no key supplied the app builds and runs exactly as before —
/// [AiSecrets.hasOpenRouterKey] is false and the fallback stays switched off,
/// so a missing secret degrades the feature rather than breaking the build.
///
/// ## What this does and does not protect
///
/// It keeps the key out of the repository and out of crash reports, which is
/// what the security requirements ask for. It does **not** make the key secret
/// from someone holding the APK: `--dart-define` values are compiled into the
/// binary and can be recovered by anyone who cares to look. That is inherent to
/// calling a keyed API directly from a mobile client, not a flaw in this file.
///
/// The only real fix is to not ship the key at all — put a thin proxy in front
/// of OpenRouter (Cloud Function or similar) that holds the key server-side and
/// authenticates callers with Firebase Auth + App Check. That is precisely what
/// the primary provider already does: Gemini goes through Firebase AI Logic,
/// which is why no Gemini key exists in this app. Treat any key shipped this
/// way as disposable: scope it tightly, keep a spend cap on it, and rotate it
/// if the build is distributed publicly.
abstract final class AiSecrets {
  /// URL of our own AI proxy (Cloudflare Worker). When set, this is used in
  /// preference to a direct OpenRouter call, because the proxy holds the API
  /// key server-side and nothing secret ships in the app. Not a secret itself —
  /// the Worker refuses to answer without a valid Firebase ID token.
  static const aiProxyUrl = String.fromEnvironment('AI_PROXY_URL');

  static bool get hasAiProxy => aiProxyUrl.trim().isNotEmpty;

  /// OpenRouter API key for the *direct* path, empty when not supplied.
  /// Prefer [aiProxyUrl]: a key compiled in here is extractable from the APK.
  static const openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');

  /// Sent as `X-Title` so usage is identifiable in the OpenRouter dashboard.
  static const openRouterAppTitle =
      String.fromEnvironment('OPENROUTER_APP_TITLE', defaultValue: 'FinGenius AI');

  static bool get hasOpenRouterKey => openRouterKey.trim().isNotEmpty;
}
