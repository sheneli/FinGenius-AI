import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../../app/config/ai_secrets.dart';
import 'fallback_provider.dart';

/// A model OpenRouter currently offers at no cost.
class FreeModel {
  const FreeModel(this.id, {this.contextLength = 0});
  final String id;
  final int contextLength;

  @override
  String toString() => id;
}

/// Thrown for any OpenRouter-side problem. Deliberately carries only a short
/// reason — never a response body, header or key — because this string ends up
/// in developer logs.
class OpenRouterException implements Exception {
  const OpenRouterException(this.reason, {this.statusCode});
  final String reason;
  final int? statusCode;

  @override
  String toString() =>
      'OpenRouterException($reason${statusCode == null ? '' : ', status $statusCode'})';
}

/// Fallback text provider, used only when Gemini has already failed.
///
/// Two things are deliberate:
///
///  * **Free models are discovered, not hard-coded.** OpenRouter's free tier
///    changes often — models are retired and renamed — so a pinned id turns
///    into a dead fallback. The model list is fetched, filtered to entries that
///    cost nothing for both prompt and completion, and cached. A hard-coded id
///    also risks silently selecting a *paid* model, which this filter makes
///    impossible.
///  * **Nothing here logs the key.** The Authorization header is built at the
///    point of the request and never interpolated into a message.
class OpenRouterClient implements FallbackProvider {
  OpenRouterClient({
    http.Client? httpClient,
    this.apiKey = AiSecrets.openRouterKey,
    this.appTitle = AiSecrets.openRouterAppTitle,
    this.timeout = const Duration(seconds: 30),
    this.modelCacheTtl = const Duration(hours: 12),
    this.maxOutputTokens = 1024,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String apiKey;
  final String appTitle;
  final Duration timeout;
  final Duration modelCacheTtl;
  final int maxOutputTokens;

  static const _base = 'https://openrouter.ai/api/v1';

  /// How many free models to try before giving up. Free models are heavily
  /// shared and frequently answer 429, so a single attempt is fragile — but
  /// this stays small so a dead fallback fails fast.
  static const _maxModelAttempts = 2;

  List<FreeModel>? _cachedModels;
  DateTime? _cachedAt;

  @override
  String get label => 'OpenRouter (direct)';

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Generates a completion, returning the text or throwing
  /// [OpenRouterException].
  @override
  Future<String> generate(String prompt) async {
    if (!isConfigured) {
      throw const OpenRouterException('no api key configured');
    }
    final models = await _freeModels();
    if (models.isEmpty) {
      throw const OpenRouterException('no free models available');
    }

    OpenRouterException? last;
    for (final model in models.take(_maxModelAttempts)) {
      try {
        return await _complete(model, prompt);
      } on OpenRouterException catch (e) {
        last = e;
        // A busy or retired free model is worth swapping; anything else
        // (auth, malformed request) will fail identically on the next model.
        final swappable = e.statusCode == 429 ||
            e.statusCode == 404 ||
            (e.statusCode ?? 0) >= 500;
        if (!swappable) break;
        developer.log('free model ${model.id} unavailable, trying next',
            name: 'OpenRouter');
      }
    }
    throw last ?? const OpenRouterException('all free models failed');
  }

  Future<String> _complete(FreeModel model, String prompt) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$_base/chat/completions'),
            headers: _headers(),
            body: jsonEncode({
              'model': model.id,
              'max_tokens': maxOutputTokens,
              'temperature': 0.4,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const OpenRouterException('timeout');
    } catch (e) {
      // Network-level; the type alone is enough to diagnose.
      throw OpenRouterException('transport ${e.runtimeType}');
    }

    if (response.statusCode != 200) {
      throw OpenRouterException('http error',
          statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const OpenRouterException('no choices returned');
      }
      final message =
          (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      // Some models return content as a list of parts rather than a string.
      final text = content is String
          ? content
          : content is List
              ? content
                  .whereType<Map<String, dynamic>>()
                  .map((part) => part['text'] ?? '')
                  .join()
              : '';
      if (text.trim().isEmpty) {
        throw const OpenRouterException('empty completion');
      }
      return text;
    } on OpenRouterException {
      rethrow;
    } catch (_) {
      throw const OpenRouterException('malformed response');
    }
  }

  /// Free models, newest fetch cached for [modelCacheTtl].
  Future<List<FreeModel>> _freeModels() async {
    final cached = _cachedModels;
    final at = _cachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < modelCacheTtl) {
      return cached;
    }

    final http.Response response;
    try {
      response = await _http
          .get(Uri.parse('$_base/models'), headers: _headers())
          .timeout(timeout);
    } on TimeoutException {
      throw const OpenRouterException('model list timeout');
    } catch (e) {
      throw OpenRouterException('model list transport ${e.runtimeType}');
    }
    if (response.statusCode != 200) {
      throw OpenRouterException('model list failed',
          statusCode: response.statusCode);
    }

    final models = parseFreeModels(response.body);
    _cachedModels = models;
    _cachedAt = DateTime.now();
    developer.log('discovered ${models.length} free models', name: 'OpenRouter');
    return models;
  }

  /// Filters OpenRouter's catalogue down to models that cost nothing.
  ///
  /// Exposed for testing because this is the guard that keeps a paid model from
  /// ever being selected. A model qualifies only when **both** the prompt and
  /// completion prices parse as zero — a missing or unparseable price is
  /// treated as paid, so an unexpected payload shape fails closed.
  static List<FreeModel> parseFreeModels(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final data = (decoded is Map<String, dynamic> ? decoded['data'] : decoded);
    if (data is! List) return const [];

    final free = <FreeModel>[];
    for (final entry in data) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id'];
      if (id is! String || id.isEmpty) continue;
      final pricing = entry['pricing'];
      if (pricing is! Map<String, dynamic>) continue;
      if (!_isZero(pricing['prompt']) || !_isZero(pricing['completion'])) {
        continue;
      }
      final context = entry['context_length'];
      free.add(FreeModel(id,
          contextLength: context is num ? context.toInt() : 0));
    }

    // Prefer the roomiest context: the assistant prompt carries a preamble plus
    // aggregated figures, and a cramped model truncates the answer.
    free.sort((a, b) => b.contextLength.compareTo(a.contextLength));
    return free;
  }

  static bool _isZero(Object? price) {
    if (price is num) return price == 0;
    if (price is String) {
      final value = double.tryParse(price);
      return value != null && value == 0;
    }
    return false;
  }

  Map<String, String> _headers() => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        // Optional attribution headers OpenRouter uses for dashboards.
        'X-Title': appTitle,
      };

  void dispose() => _http.close();
}
