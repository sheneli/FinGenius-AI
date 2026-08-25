/// Normalises merchant strings so detection algorithms compare like with like.
/// "KEELLS SUPER - UNION PL #0042" and "Keells Super Union Place" → "keells super".
class MerchantNormalizer {
  MerchantNormalizer._();

  static final _noise = RegExp(
    r'\b(pvt|ltd|plc|inc|llc|store|super|supermarket|online|payment|pos|ref|txn|branch|www|com|net|org)\b',
    caseSensitive: false,
  );
  static final _numbersAndCodes = RegExp(r'[#*]?\d[\d\-/]*');
  static final _punct = RegExp(r'[^\w\s]');
  static final _spaces = RegExp(r'\s+');

  static String normalize(String raw) {
    var s = raw.toLowerCase();
    s = s.replaceAll(_numbersAndCodes, ' ');
    s = s.replaceAll(_punct, ' ');
    s = s.replaceAll(_noise, ' ');
    s = s.replaceAll(_spaces, ' ').trim();
    // Keep the two most significant tokens — stable across branch suffixes.
    final tokens = s.split(' ').where((t) => t.length > 1).take(2);
    return tokens.join(' ');
  }

  /// Jaccard similarity over character bigrams — cheap fuzzy match for
  /// duplicate detection (handles OCR typos like "keels" vs "keells").
  static double similarity(String a, String b) {
    final na = normalize(a), nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return na == nb ? 1 : 0;
    if (na == nb) return 1;
    final ga = _bigrams(na), gb = _bigrams(nb);
    final inter = ga.intersection(gb).length;
    final union = ga.union(gb).length;
    return union == 0 ? 0 : inter / union;
  }

  static Set<String> _bigrams(String s) {
    final out = <String>{};
    for (var i = 0; i < s.length - 1; i++) {
      out.add(s.substring(i, i + 2));
    }
    return out;
  }
}
