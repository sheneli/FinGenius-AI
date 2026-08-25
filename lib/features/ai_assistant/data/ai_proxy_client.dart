import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../../app/config/ai_secrets.dart';
import 'fallback_provider.dart';

/// Raised for any proxy-side problem. Carries a short reason and status only —
/// never a response body — because this string reaches developer logs.
class AiProxyException implements Exception {
  const AiProxyException(this.reason, {this.statusCode});
  final String reason;
  final int? statusCode;

  @override
  String toString() =>
      'AiProxyException($reason${statusCode == null ? '' : ', status $statusCode'})';
}

/// Fallback provider that talks to our own Cloudflare Worker instead of to
/// OpenRouter directly.
///
/// The app sends the signed-in user's **Firebase ID token** and nothing else of
/// value. The Worker verifies that token, holds the OpenRouter key as a Worker
/// secret, picks a free model and forwards the request. This is the only
/// arrangement in which the key is genuinely secret: an attacker with the APK
/// gets a proxy URL that refuses to answer without a valid token belonging to a
/// real account in this Firebase project.
///
/// It also removes the app's dependency on Firebase AI Logic being enabled —
/// the assistant works through this path with no Google Cloud configuration.
class AiProxyClient implements FallbackProvider {
  AiProxyClient({
    required this.idTokenProvider,
    http.Client? httpClient,
    this.endpoint = AiSecrets.aiProxyUrl,
    this.timeout = const Duration(seconds: 45),
  }) : _http = httpClient ?? http.Client();

  /// Supplies a fresh Firebase ID token, or null when nobody is signed in.
  final Future<String?> Function() idTokenProvider;

  final http.Client _http;
  final String endpoint;
  final Duration timeout;

  @override
  String get label => 'AI proxy';

  @override
  bool get isConfigured => endpoint.trim().isNotEmpty;

  @override
  Future<String> generate(String prompt) async {
    if (!isConfigured) {
      throw const AiProxyException('no proxy endpoint configured');
    }

    final token = await idTokenProvider();
    if (token == null || token.isEmpty) {
      // Unauthenticated callers are rejected by the Worker anyway; failing here
      // saves a pointless round-trip.
      throw const AiProxyException('not signed in');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiProxyException('timeout');
    } catch (e) {
      throw AiProxyException('transport ${e.runtimeType}');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiProxyException('rejected credentials',
          statusCode: response.statusCode);
    }
    if (response.statusCode == 429) {
      throw const AiProxyException('rate limited', statusCode: 429);
    }
    if (response.statusCode != 200) {
      throw AiProxyException('http error', statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text = body['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const AiProxyException('empty completion');
      }
      final model = body['model'];
      if (model is String && model.isNotEmpty) {
        developer.log('proxy used free model $model', name: 'AiProxy');
      }
      return text;
    } on AiProxyException {
      rethrow;
    } catch (_) {
      throw const AiProxyException('malformed response');
    }
  }

  void dispose() => _http.close();
}
