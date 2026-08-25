import 'dart:convert';

/// AI output is never trusted directly. Structured responses are validated
/// here before display or persistence; prose replies pass a safety lint that
/// strips or rejects unsafe financial-advice patterns per docs/financial_safety.
class AiValidationResult<T> {
  const AiValidationResult.ok(this.value)
      : isValid = true,
        reason = null;
  const AiValidationResult.invalid(this.reason)
      : isValid = false,
        value = null;
  final bool isValid;
  final T? value;
  final String? reason;
}

class AiOutputValidator {
  const AiOutputValidator();

  static final _guaranteePatterns = RegExp(
    r'\b(guaranteed\s+(returns?|profit|gains?)|risk[- ]free\s+(investment|return)|cannot\s+lose|certain\s+to\s+(rise|double|profit))\b',
    caseSensitive: false,
  );
  // Phrase match tolerates sentence-initial capitals ("You should buy…"),
  // but the ticker stays uppercase-only so ordinary phrases like "you should
  // buy groceries" are not over-blocked.
  static final _instructionPatterns = RegExp(
    r'\b[Yy]ou\s+(?:[Ss]hould|[Mm]ust)\s+(?:[Bb]uy|[Ss]ell|[Ss]hort)\s+[A-Z]{2,6}\b|\b[Aa]ll[- ][Ii]n\b',
  );

  /// Validates a category suggestion JSON: {"categoryId": "...", "confidence": 0.x}
  AiValidationResult<({String categoryId, double confidence})> validateCategorySuggestion(
    String raw,
    Set<String> knownCategoryIds,
  ) {
    final map = _tryDecode(raw);
    if (map == null) return const AiValidationResult.invalid('Response was not valid JSON');
    final id = map['categoryId'];
    final conf = map['confidence'];
    if (id is! String || !knownCategoryIds.contains(id)) {
      return const AiValidationResult.invalid('Unknown category id');
    }
    if (conf is! num || conf < 0 || conf > 1) {
      return const AiValidationResult.invalid('Confidence out of range');
    }
    return AiValidationResult.ok((categoryId: id, confidence: conf.toDouble()));
  }

  /// Validates receipt-normalisation JSON:
  /// {"merchant": str?, "totalMinor": int?, "dateIso": str?, "currency": str?}
  AiValidationResult<Map<String, Object?>> validateReceiptFields(String raw) {
    final map = _tryDecode(raw);
    if (map == null) return const AiValidationResult.invalid('Response was not valid JSON');
    final out = <String, Object?>{};
    final merchant = map['merchant'];
    if (merchant is String && merchant.trim().isNotEmpty && merchant.length <= 80) {
      out['merchant'] = merchant.trim();
    }
    final total = map['totalMinor'];
    if (total is num && total > 0 && total < 100000000000) out['totalMinor'] = total.toInt();
    final dateIso = map['dateIso'];
    if (dateIso is String) {
      final d = DateTime.tryParse(dateIso);
      if (d != null && d.isBefore(DateTime.now().add(const Duration(days: 2)))) {
        out['dateIso'] = dateIso;
      }
    }
    final currency = map['currency'];
    if (currency is String && RegExp(r'^[A-Z]{3}$').hasMatch(currency)) out['currency'] = currency;
    if (out.isEmpty) return const AiValidationResult.invalid('No usable fields');
    return AiValidationResult.ok(out);
  }

  /// Safety lint for assistant prose. Returns invalid for content that breaks
  /// the financial-safety policy (guarantees, direct trade instructions).
  AiValidationResult<String> validateAssistantReply(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const AiValidationResult.invalid('Empty response');
    if (text.length > 8000) return const AiValidationResult.invalid('Response too long');
    if (_guaranteePatterns.hasMatch(text)) {
      return const AiValidationResult.invalid('Response promised guaranteed outcomes');
    }
    if (_instructionPatterns.hasMatch(text)) {
      return const AiValidationResult.invalid('Response gave direct trading instructions');
    }
    return AiValidationResult.ok(text);
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    // Models sometimes wrap JSON in markdown fences — strip them defensively.
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(json)?\s*'), '').replaceFirst(RegExp(r'```\s*$'), '');
    }
    try {
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
