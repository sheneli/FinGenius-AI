/// A secondary text provider, consulted only after Gemini has failed.
///
/// Two implementations exist and they differ only in where the OpenRouter key
/// lives:
///
///  * [AiProxyClient] — calls a Cloudflare Worker that holds the key
///    server-side and verifies the caller's Firebase ID token. Nothing secret
///    ships in the app. **Preferred.**
///  * [OpenRouterClient] — calls OpenRouter directly with a key compiled into
///    the binary. Simpler to set up, but the key is extractable from the APK.
///
/// The gateway is written against this interface so the choice is a deployment
/// decision rather than a code change.
abstract class FallbackProvider {
  /// False when the provider has no usable configuration, in which case the
  /// gateway skips it entirely and surfaces Gemini's own error.
  bool get isConfigured;

  /// Returns generated text, or throws. Implementations must never include
  /// credentials in thrown messages — they are logged.
  Future<String> generate(String prompt);

  /// Short label for diagnostics. Never contains secrets.
  String get label;
}
