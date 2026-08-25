import 'merchant_normalizer.dart';

/// Layered expense categorisation (Strategy pipeline):
///   1. user-defined rules (exact normalised merchant → category)
///   2. learned corrections (past user fixes, most recent wins)
///   3. deterministic keyword map (seed knowledge)
///   4. → AI fallback handled by the caller only when this returns low confidence
/// Every result carries provenance + confidence so the UI can show *why* and
/// let the user correct it; corrections feed back into layer 2.
class CategorySuggestion {
  const CategorySuggestion(this.categoryId, this.confidence, this.source);
  final String categoryId;
  final double confidence;
  final String source; // rule | learned | keyword | fallback

  static const fallback = CategorySuggestion('other', 0.1, 'fallback');
}

class Categorizer {
  Categorizer({Map<String, String>? userRules, Map<String, String>? learnedCorrections})
      : _userRules = {...?userRules},
        _learned = {...?learnedCorrections};

  final Map<String, String> _userRules; // normalized merchant -> categoryId
  final Map<String, String> _learned;

  static const Map<String, String> _keywords = {
    'grocer': 'groceries', 'supermarket': 'groceries', 'keells': 'groceries',
    'cargills': 'groceries', 'arpico': 'groceries', 'spar': 'groceries', 'food city': 'groceries',
    'restaurant': 'dining', 'cafe': 'dining', 'coffee': 'dining', 'pizza': 'dining',
    'burger': 'dining', 'kfc': 'dining', 'mcdonald': 'dining', 'bakery': 'dining',
    'uber': 'transport', 'pickme': 'transport', 'taxi': 'transport', 'fuel': 'transport',
    'petrol': 'transport', 'bus': 'transport', 'train': 'transport', 'parking': 'transport',
    'netflix': 'entertainment', 'spotify': 'entertainment', 'cinema': 'entertainment',
    'game': 'entertainment', 'youtube': 'entertainment',
    'pharmacy': 'health', 'hospital': 'health', 'clinic': 'health', 'doctor': 'health',
    'gym': 'health', 'dental': 'health',
    'electric': 'utilities', 'water board': 'utilities', 'dialog': 'utilities',
    'mobitel': 'utilities', 'slt': 'utilities', 'internet': 'utilities', 'broadband': 'utilities',
    'rent': 'housing', 'landlord': 'housing', 'apartment': 'housing',
    'school': 'education', 'course': 'education', 'udemy': 'education', 'tuition': 'education',
    'book': 'education', 'campus': 'education',
    'clothing': 'shopping', 'fashion': 'shopping', 'mall': 'shopping', 'daraz': 'shopping',
    'amazon': 'shopping', 'ebay': 'shopping',
    'insurance': 'insurance', 'premium': 'insurance',
    'salary': 'salary', 'wages': 'salary', 'freelance': 'freelance', 'invoice': 'freelance',
    'interest': 'investment', 'dividend': 'investment',
  };

  CategorySuggestion suggest(String merchant, {String note = ''}) {
    final normalized = MerchantNormalizer.normalize(merchant);
    final haystack = '${merchant.toLowerCase()} ${note.toLowerCase()}';

    if (normalized.isNotEmpty && _userRules.containsKey(normalized)) {
      return CategorySuggestion(_userRules[normalized]!, 0.98, 'rule');
    }
    if (normalized.isNotEmpty && _learned.containsKey(normalized)) {
      return CategorySuggestion(_learned[normalized]!, 0.90, 'learned');
    }
    for (final entry in _keywords.entries) {
      if (haystack.contains(entry.key)) {
        return CategorySuggestion(entry.value, 0.70, 'keyword');
      }
    }
    return CategorySuggestion.fallback;
  }

  /// Records a user correction — future suggestions for this merchant use it.
  void learn(String merchant, String categoryId) {
    final normalized = MerchantNormalizer.normalize(merchant);
    if (normalized.isNotEmpty) _learned[normalized] = categoryId;
  }

  /// True when the caller should consider the AI fallback (layer 4).
  bool needsAiFallback(CategorySuggestion s) => s.confidence < 0.5;
}
