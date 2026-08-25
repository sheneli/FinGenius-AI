import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../app/config/feature_flags.dart';
import 'fallback_provider.dart';
import 'openrouter_client.dart';
import '../domain/ai_output_validator.dart';
import '../domain/financial_aggregates.dart';

/// Which upstream answered a request.
enum AiProvider {
  /// Primary: Gemini through Firebase AI Logic. No API key ships in the app.
  gemini,

  /// Fallback: OpenRouter free tier, used only after Gemini has failed.
  openRouter,
}

/// Single entry point for Gemini access via **Firebase AI Logic** — no API key
/// ships in the app; requests are attested by Firebase Auth + App Check.
/// Controls applied to every call: feature flag, per-user daily rate limit,
/// timeout, single retry for transient errors, output validation, and a
/// deterministic local fallback so the product degrades gracefully.
///
/// Gemini is always tried first. If it fails — API error, timeout, rate limit,
/// disabled service, or a transport problem — the same prompt is retried once
/// through OpenRouter's free tier (see [OpenRouterClient]). The daily quota is
/// consumed once per *successful* answer regardless of which provider served
/// it, so a fallback does not cost the user two requests.
class AiGateway {
  AiGateway({
    required this.flags,
    required this.metaBox,
    GenerativeModel? modelOverride,
    Future<String?> Function(String prompt)? rawGenerateOverride,
    FallbackProvider? fallback,
  })  : _modelOverride = modelOverride,
        _rawGenerateOverride = rawGenerateOverride,
        _fallback = fallback ?? OpenRouterClient();

  final FeatureFlags flags;
  final Box<dynamic> metaBox;
  final GenerativeModel? _modelOverride;

  /// Test seam: replaces the SDK call (returns the raw text or throws).
  final Future<String?> Function(String prompt)? _rawGenerateOverride;

  /// Secondary provider. Only consulted after Gemini has already failed, and
  /// only when a key was supplied at build time.
  final FallbackProvider _fallback;

  /// Which provider answered the most recent successful request. Recorded for
  /// diagnostics and asserted in tests; never contains credentials.
  AiProvider? lastProviderUsed;

  static const _timeout = Duration(seconds: 30);
  static const _validator = AiOutputValidator();

  static const _systemPreamble = '''
You are FinGenius, a careful financial-wellness assistant inside a personal
finance app. You only discuss the user's own aggregated finances and general
financial-wellness education.
Rules you must never break:
- Never guarantee outcomes or returns.
- Never tell the user to buy or sell any specific security, crypto asset, or product.
- Distinguish facts (from the provided data) from suggestions.
- State uncertainty honestly; the provided data may be incomplete.
- For high-impact decisions (loans, investments, tax), recommend consulting a
  qualified professional.
- Be encouraging and practical. Never shame the user.
- End with this exact sentence: "This is educational guidance, not professional financial advice."''';

  GenerativeModel _model() =>
      _modelOverride ??
      FirebaseAI.googleAI().generativeModel(
        model: flags.aiModel,
        generationConfig: GenerationConfig(
          maxOutputTokens: flags.aiMaxOutputTokens,
          temperature: 0.4,
        ),
      );

  /// Free-form question grounded ONLY in minimised aggregates — the user's raw
  /// transaction history is never sent (data minimisation, docs/privacy_data_flow.md).
  Future<Result<String>> ask(String question, FinancialAggregates aggregates) async {
    final gate = _gate();
    if (gate != null) return Err(gate);
    final prompt = '$_systemPreamble\n\n'
        'User data (aggregated, ${aggregates.currency}):\n${aggregates.toPromptBlock()}\n\n'
        'User question: ${question.trim()}';
    final result = await _generate(prompt);
    return result.when(
      ok: (text) {
        final validated = _validator.validateAssistantReply(text);
        if (!validated.isValid) {
          return const Err(AiFailure('The AI reply did not pass safety checks. Try rephrasing your question.'));
        }
        return Ok(validated.value!);
      },
      err: Err.new,
    );
  }

  /// Monthly narrative summary from aggregates.
  Future<Result<String>> monthlySummary(FinancialAggregates aggregates) => ask(
        'Write a short (max 180 words) monthly financial summary: what went well, '
        'what to watch, and one concrete next step.',
        aggregates,
      );

  /// Category suggestion for an uncertain merchant. Structured + validated.
  Future<Result<({String categoryId, double confidence})>> categorize(
    String merchant,
    String note,
    Set<String> knownCategoryIds,
  ) async {
    final gate = _gate();
    if (gate != null) return Err(gate);
    final prompt = 'Classify this expense into exactly one category id from: '
        '${knownCategoryIds.join(', ')}.\n'
        'Merchant: "$merchant". Note: "$note".\n'
        'Reply with ONLY JSON: {"categoryId": "<id>", "confidence": <0..1>}';
    final result = await _generate(prompt);
    return result.when(
      ok: (text) {
        final v = _validator.validateCategorySuggestion(text, knownCategoryIds);
        return v.isValid
            ? Ok(v.value!)
            : Err(AiFailure(v.reason ?? 'Invalid AI response'));
      },
      err: Err.new,
    );
  }

  /// Normalises low-confidence OCR fields. Only redacted receipt lines are sent.
  Future<Result<Map<String, Object?>>> normalizeReceipt(List<String> redactedLines) async {
    if (!flags.ocrAiNormalization) return const Err(AiFailure('AI normalisation is disabled'));
    final gate = _gate();
    if (gate != null) return Err(gate);
    final prompt = 'Extract fields from these receipt text lines.\n'
        'Reply with ONLY JSON: {"merchant": str|null, "totalMinor": int|null '
        '(amount in cents), "dateIso": "YYYY-MM-DD"|null, "currency": "XXX"|null}\n'
        'Lines:\n${redactedLines.take(40).join('\n')}';
    final result = await _generate(prompt);
    return result.when(
      ok: (text) {
        final v = _validator.validateReceiptFields(text);
        return v.isValid ? Ok(v.value!) : Err(AiFailure(v.reason ?? 'Invalid AI response'));
      },
      err: Err.new,
    );
  }

  Failure? _gate() {
    if (!flags.aiAssistant) {
      return const AiFailure('The AI assistant is currently unavailable.');
    }
    // Quota is only checked here; it is consumed on SUCCESS in [_generate],
    // so failed attempts never burn the user's daily allowance.
    if (_quotaUsedToday() >= flags.aiDailyLimit) {
      return const RateLimitFailure();
    }
    return null;
  }

  Future<String?> _rawGenerate(String prompt) async {
    if (_rawGenerateOverride != null) {
      return _rawGenerateOverride(prompt).timeout(_timeout);
    }
    final response =
        await _model().generateContent([Content.text(prompt)]).timeout(_timeout);
    return response.text;
  }

  /// Runs a prompt through Gemini, falling back to OpenRouter if — and only
  /// if — Gemini itself failed.
  ///
  /// The providers are never called in parallel or speculatively: OpenRouter is
  /// reached only from the failure paths below, so a healthy Gemini request
  /// costs exactly one upstream call.
  Future<Result<String>> _generate(String prompt) async {
    final primary = await _generateWithGemini(prompt);
    return primary.when(
      ok: (text) {
        lastProviderUsed = AiProvider.gemini;
        debugPrint('AI served by Gemini');
        _consumeQuota();
        return Ok(text);
      },
      err: (geminiFailure) => _generateWithFallback(prompt, geminiFailure),
    );
  }

  /// Gemini attempt, including its existing single retry for transient errors.
  /// Quota is deliberately *not* consumed here — see [_generate].
  Future<Result<String>> _generateWithGemini(String prompt,
      {bool retried = false}) async {
    try {
      final text = await _rawGenerate(prompt);
      if (text == null || text.trim().isEmpty) {
        return const Err(
            AiFailure('The AI returned an empty response.', retriable: true));
      }
      return Ok(text);
    } on TimeoutException {
      if (!retried) return _generateWithGemini(prompt, retried: true);
      return const Err(AiFailure(
          'The AI took too long to respond. Please try again.',
          retriable: true));
    } catch (e) {
      // Sanitized diagnostics for developers: type + message only, no prompt
      // contents and no credentials (the SDK holds none client-side anyway).
      // debugPrint, not developer.log: dart:developer output goes to the VM
      // service and never appears in logcat for a release build, which is
      // precisely where a failing AI call has to be diagnosable.
      debugPrint('AI Gemini failed: ${e.runtimeType}: ${_sanitize('$e')}');
      final mapped = _mapError(e);
      // Only transient failures deserve an automatic retry.
      if (mapped.retriable && !retried) {
        return _generateWithGemini(prompt, retried: true);
      }
      return Err(mapped);
    }
  }

  /// Second and final attempt, via OpenRouter's free tier.
  ///
  /// When the fallback is unavailable or also fails, the *Gemini* failure is
  /// what the user sees: it describes the primary provider, which is the one
  /// they are nominally using, and it has already been written as an actionable
  /// message. Surfacing an OpenRouter-specific error instead would be confusing
  /// and could leak provider detail into the UI.
  Future<Result<String>> _generateWithFallback(
      String prompt, Failure geminiFailure) async {
    if (!_fallback.isConfigured) {
      debugPrint('AI Gemini failed, no fallback configured');
      return Err(geminiFailure);
    }

    debugPrint('AI falling back to ${_fallback.label}');
    try {
      final text = await _fallback.generate(prompt);
      if (text.trim().isEmpty) {
        return Err(geminiFailure);
      }
      lastProviderUsed = AiProvider.openRouter;
      debugPrint('AI served by ${_fallback.label}');
      _consumeQuota();
      return Ok(text);
    } catch (e) {
      // Both fallback exceptions carry only a short reason, never a body or
      // key, but sanitize anyway so this stays safe if that ever changes.
      debugPrint('AI fallback (${_fallback.label}) failed: ${_sanitize('$e')}');
      return const Err(AiFailure(
        'Both AI services are unavailable right now. Please check your '
        'connection and try again in a moment.',
        retriable: true,
      ));
    }
  }

  /// Translate provider exceptions into actionable, non-sensitive messages.
  AiFailure _mapError(Object e) {
    final s = '$e'.toLowerCase();
    if (s.contains('api_not_enabled') ||
        s.contains('service_disabled') ||
        s.contains('has not been used') ||
        s.contains('firebasevertexai.googleapis.com') && s.contains('403') ||
        s.contains('permission')) {
      // Names what is actually wrong and what still works. The old wording
      // told the user to "ask the administrator" — on a solo project they are
      // the administrator, so that was a dead end. Totals questions are
      // answered on-device by AssistantEngine and need none of this.
      return const AiFailure(
        'Free-form questions need an AI service that is not switched on for '
        'this app yet. You can still ask about totals — try "how much did I '
        'spend this month" — and all voice commands keep working.',
        retriable: false,
      );
    }
    if (s.contains('quota') || s.contains('resource_exhausted') || s.contains('429')) {
      return const AiFailure(
        'The AI service is temporarily over capacity. Try again in a minute.',
        retriable: true,
      );
    }
    // Model retirement. Google withdraws model ids on its own schedule, and the
    // wording carries no status code — the real response was:
    //   "This model models/gemini-2.5-flash is no longer available to new
    //    users. Please update your code to use a newer model"
    // That matches neither "not found" nor any status word, so it fell through
    // to the generic branch and read as a transient glitch worth retrying. It is
    // not transient: every request fails until the configured id changes.
    if (s.contains('no longer available') ||
        s.contains('is deprecated') ||
        s.contains('has been discontinued') ||
        (s.contains('not found') && s.contains('model'))) {
      return const AiFailure(
        'The AI model this app uses has been retired. Update the app — totals '
        'questions like "how much did I spend this month" keep working in the '
        'meantime.',
        retriable: false,
      );
    }
    if (s.contains('unauthenticated') || s.contains('app check') || s.contains('401')) {
      return const AiFailure(
        'The AI service rejected this app\'s credentials. Sign out and back in, '
        'or contact support if it persists.',
        retriable: false,
      );
    }
    if (s.contains('socket') || s.contains('network') || s.contains('connection')) {
      return const AiFailure(
        'Could not reach the AI service. Check your connection and try again.',
        retriable: true,
      );
    }
    // Deliberately does not blame the connection: this branch is reached for
    // any unrecognised provider error, and saying "check your connection" when
    // the network is fine sends the user to fix something that is not broken.
    return AiFailure(
      'The AI service could not answer that. Try again in a moment — totals '
      'questions like "how much did I spend this month" work regardless.',
      retriable: true,
      cause: e,
    );
  }

  /// Strip anything URL-query-like or token-like before logging.
  String _sanitize(String message) => message
      .replaceAll(RegExp(r'key=[^&\s]+'), 'key=***')
      .replaceAll(RegExp(r'Bearer\s+\S+'), 'Bearer ***');

  /// Local per-user daily quota (defence in depth alongside server-side limits).
  int _quotaUsedToday() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return (metaBox.get('ai_quota_$today') as int?) ?? 0;
  }

  void _consumeQuota() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    metaBox.put('ai_quota_$today', _quotaUsedToday() + 1);
  }

  int remainingQuota() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final used = (metaBox.get('ai_quota_$today') as int?) ?? 0;
    return (flags.aiDailyLimit - used).clamp(0, flags.aiDailyLimit);
  }
}
