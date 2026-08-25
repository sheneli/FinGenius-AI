import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remote Config-backed feature flags with safe local defaults.
/// Anything requiring unfinished console setup ships OFF by default.
class FeatureFlags {
  const FeatureFlags(this._rc);
  final FirebaseRemoteConfig? _rc;

  /// Default Gemini model id, in one place because it is needed both as a
  /// Remote Config default and as the getter's fallback — those two drifted
  /// apart previously, so a change to one silently did nothing.
  ///
  /// A *stable* id, per Google's guidance for production apps. The previous
  /// default `gemini-2.5-flash` is closed to projects that had not already
  /// used it; this project got
  ///   "This model models/gemini-2.5-flash is no longer available to new users"
  /// on every free-form question, which is what made the assistant look broken.
  ///
  /// Deliberately not a `-latest` alias: those hot-swap underneath you, and
  /// replies here must satisfy [AiOutputValidator], so a silent model change
  /// could start failing output validation with no deploy. Override without
  /// shipping a build by setting `ai_model` in Remote Config.
  static const defaultAiModel = 'gemini-3.6-flash';

  static const defaults = <String, dynamic>{
    // Requires OAuth client + SHA fingerprints in Firebase console — see
    // docs/setup/firebase_setup.md. Never enable without console config.
    'google_sign_in_enabled': false,
    // Requires AI Logic enabled + billing in console.
    'ai_assistant_enabled': true,
    'ai_model': defaultAiModel,
    'ai_daily_request_limit': 40,
    'ai_max_output_tokens': 1024,
    'ocr_ai_normalization_enabled': true,
    'subscription_detection_enabled': true,
    'voice_entry_enabled': true,
  };

  bool get googleSignIn => _rc?.getBool('google_sign_in_enabled') ?? false;
  bool get aiAssistant => _rc?.getBool('ai_assistant_enabled') ?? true;
  String get aiModel => _valueOr('ai_model', defaultAiModel);
  int get aiDailyLimit => _rc?.getInt('ai_daily_request_limit') ?? 40;
  int get aiMaxOutputTokens => _rc?.getInt('ai_max_output_tokens') ?? 1024;
  bool get ocrAiNormalization => _rc?.getBool('ocr_ai_normalization_enabled') ?? true;
  bool get subscriptionDetection => _rc?.getBool('subscription_detection_enabled') ?? true;
  bool get voiceEntry => _rc?.getBool('voice_entry_enabled') ?? true;

  String _valueOr(String key, String fallback) {
    final v = _rc?.getString(key);
    return (v == null || v.isEmpty) ? fallback : v;
  }

  static Future<FirebaseRemoteConfig?> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(hours: 6),
      ));
      await rc.setDefaults(Map<String, Object>.from(defaults));
      // Fetch failures are non-fatal — defaults keep the app working offline.
      await rc.fetchAndActivate();
      return rc;
    } catch (_) {
      return null;
    }
  }
}

/// Fetches Remote Config lazily, off the startup path.
///
/// This used to be awaited in `main()` before the first frame, so a slow fetch
/// delayed the login screen by however long the round-trip took. Resolving it
/// here means the app renders immediately and the flags update when the fetch
/// lands. Until then [featureFlagsProvider] serves [FeatureFlags.defaults] —
/// the same safe local values already used whenever a fetch fails.
final remoteConfigProvider =
    FutureProvider<FirebaseRemoteConfig?>((_) => FeatureFlags.init());

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags(ref.watch(remoteConfigProvider).valueOrNull),
);
