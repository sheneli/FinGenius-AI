import '../../../app/config/ai_secrets.dart';
import 'ai_proxy_client.dart';
import 'fallback_provider.dart';
import 'openrouter_client.dart';

/// Chooses the fallback provider from what the build was given.
///
/// Order is deliberate. The proxy wins whenever a URL is configured, because it
/// is the only arrangement where the OpenRouter key is genuinely secret — the
/// direct path compiles the key into the APK, where anyone can extract it. The
/// direct client remains as a convenience for local development and as a
/// last resort if no proxy has been deployed.
///
/// When neither is configured this returns a provider whose `isConfigured` is
/// false; the gateway then skips the fallback entirely and surfaces Gemini's own
/// error, exactly as it did before any of this existed.
FallbackProvider createFallbackProvider({
  required Future<String?> Function() idTokenProvider,
}) {
  if (AiSecrets.hasAiProxy) {
    return AiProxyClient(idTokenProvider: idTokenProvider);
  }
  return OpenRouterClient();
}
