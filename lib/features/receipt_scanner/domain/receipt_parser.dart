import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Parses raw OCR text lines from ML Kit into structured receipt fields with
/// per-field confidence. Pure Dart — fully unit-testable without a device.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    this.merchantConfidence = 0,
    this.totalMinor,
    this.totalConfidence = 0,
    this.taxMinor,
    this.date,
    this.dateConfidence = 0,
    this.currency,
    this.paymentMethod,
    this.receiptNumber,
    this.merchantPhone,
    this.lineItems = const [],
  });

  final String? merchant;
  final double merchantConfidence;
  final int? totalMinor;
  final double totalConfidence;
  final int? taxMinor;
  final DateTime? date;
  final double dateConfidence;
  final String? currency;

  /// "Cash", "Card", "Visa"… as printed. Recorded with the receipt so the
  /// entry can be reconciled against a statement later.
  final String? paymentMethod;

  /// Invoice / bill / receipt number as printed. The strongest signal for
  /// recognising the *same* receipt scanned twice, since two visits to one
  /// shop can share a merchant, date and total but never a receipt number.
  final String? receiptNumber;

  /// Vendor contact number, kept as part of the store details.
  final String? merchantPhone;
  final List<ReceiptLineItem> lineItems;

  bool get isUsable => totalMinor != null || merchant != null;

  /// Stable fingerprint for duplicate detection across rescans of one receipt.
  ///
  /// A printed receipt number identifies the transaction exactly, so it is
  /// preferred when present — merchant + total + date alone cannot tell two
  /// identical purchases made on the same day apart. Receipts without a number
  /// keep the original basis, so fingerprints already stored stay valid.
  String get fingerprint {
    final number = receiptNumber;
    final basis = (number != null && number.isNotEmpty)
        ? '${merchant ?? ''}|#$number'
        : '${merchant ?? ''}|${totalMinor ?? ''}|${date?.toIso8601String().substring(0, 10) ?? ''}';
    return sha256.convert(utf8.encode(basis)).toString();
  }
}

class ReceiptLineItem {
  const ReceiptLineItem(this.description, this.amountMinor);
  final String description;
  final int amountMinor;
}

class ReceiptParser {
  const ReceiptParser();

  /// One money-shaped token. Deliberately permissive about decimals — plenty
  /// of receipts print "TOTAL 1,250" or "Rs 1250/-" with no cents at all —
  /// and the qualification in [_MoneyToken.looksLikeMoney] is what keeps
  /// quantities, years and phone numbers from being read as amounts.
  static final _money = RegExp(
    r'(?<![\w.,])(rs\.?|lkr|usd|\$|£|€)?\s*'
    r'(\d{1,3}(?:,\d{3})+|\d+)'
    r'(?:\.(\d{1,2}))?'
    r'\s*(/[-=])?(?![\d])',
    caseSensitive: false,
  );

  /// "GRAND TOTAL", "AMOUNT DUE" — unambiguous, and they beat a bare "TOTAL".
  static final _strongTotal = RegExp(
    r'\b(grand\s*total|nett?\s*(?:total|amount|payable)|total\s*(?:payable|due)'
    r'|amount\s*(?:due|payable)|balance\s*due)\b',
    caseSensitive: false,
  );
  static final _plainTotal = RegExp(r'\btotals?\b', caseSensitive: false);
  static final _subTotal = RegExp(r'\bsub[\s-]*total\b', caseSensitive: false);
  static final _taxKeywords = RegExp(
      r'\b(vat|tax|gst|levy|ssl|service\s*charge)\b',
      caseSensitive: false);

  /// Lines whose amount must never be mistaken for the bill total — the
  /// cash tendered, the change given back, loyalty points, item counts.
  static final _notATotal = RegExp(
    r'\b(sav(?:e|ing|ings)|discount|qty|quantity|items?|change|cash|tendered'
    r'|points?|loyalty|round(?:ing|ed)?|deposit|advance)\b',
    caseSensitive: false,
  );

  static final _skipAsMerchant = RegExp(
    r'\b(receipt|invoice|welcome|thank|tel|phone|www\.|no\.|order|cashier|date'
    r'|time|bill|vat|reg)\b|\d{5,}',
    caseSensitive: false,
  );

  static final _dateKeyword =
      RegExp(r'\b(date|dated|issued|on)\b', caseSensitive: false);

  /// "Invoice No 8842190", "Bill No: 42/A", "Receipt #12345", "Ref: INV-77".
  /// The label is required — a bare number is far more likely to be a phone
  /// number, a till number or part of an address.
  static final _receiptNumber = RegExp(
    r'\b(?:invoice|receipt|bill|order|ref(?:erence)?|inv|trans(?:action)?|txn|doc)'
    r'\s*(?:no\.?|number|#|id)?\s*[:#]?\s*'
    r'([A-Z]{0,4}[-/]?\d[\dA-Z/-]{2,19})\b',
    caseSensitive: false,
  );

  /// Printed contact number, including the Sri Lankan 011-2345678 shape.
  static final _phone = RegExp(
    r'\b(?:tel|phone|hotline|mob(?:ile)?|contact)\b[^\d+]{0,6}'
    r'(\+?[\d][\d\s\-()]{6,17}\d)',
    caseSensitive: false,
  );

  static final _paymentMethods = <RegExp, String>{
    RegExp(r'\bvisa\b', caseSensitive: false): 'Visa',
    RegExp(r'\bmaster\s*(?:card)?\b', caseSensitive: false): 'Mastercard',
    RegExp(r'\bamex|american\s*express\b', caseSensitive: false): 'Amex',
    RegExp(r'\b(credit|debit)\s*card\b', caseSensitive: false): 'Card',
    RegExp(r'\bcard\b', caseSensitive: false): 'Card',
    RegExp(r'\b(cash|tendered)\b', caseSensitive: false): 'Cash',
    RegExp(r'\b(qr|online|upi|frimi|ez\s*cash)\b', caseSensitive: false):
        'Online',
  };

  static final _currencyHints = <RegExp, String>{
    RegExp(r'\brs\b|\brs\.|\blkr\b', caseSensitive: false): 'LKR',
    RegExp(r'\$|\busd\b', caseSensitive: false): 'USD',
    RegExp(r'£|\bgbp\b', caseSensitive: false): 'GBP',
    RegExp(r'€|\beur\b', caseSensitive: false): 'EUR',
  };

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Anything above this is a reference number, not a price.
  static const _maxPlausibleMajor = 100000000;

  ParsedReceipt parse(List<String> lines) {
    if (lines.isEmpty) return const ParsedReceipt();
    final trimmed =
        lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (trimmed.isEmpty) return const ParsedReceipt();

    final joined = trimmed.join(' ');

    // ── Merchant: first "clean" line near the top ─────────────────────────
    String? merchant;
    var merchantConfidence = 0.0;
    for (var i = 0; i < trimmed.length && i < 5; i++) {
      final line = trimmed[i];
      if (line.length < 3 || _skipAsMerchant.hasMatch(line)) continue;
      if (_tokensIn(line).any((t) => t.looksLikeMoney)) continue;
      merchant = _titleCase(line);
      merchantConfidence = i == 0 ? 0.8 : 0.6;
      break;
    }

    // ── Currency ──────────────────────────────────────────────────────────
    String? currency;
    for (final e in _currencyHints.entries) {
      if (e.key.hasMatch(joined)) {
        currency = e.value;
        break;
      }
    }

    // ── Total: score each candidate line, strongest (then latest) wins ────
    int? totalMinor;
    var totalScore = -1;
    int? taxMinor;
    final allAmounts = <int>[];

    for (final line in trimmed) {
      final isTax = _taxKeywords.hasMatch(line);
      final excluded = _notATotal.hasMatch(line);
      final score = isTax || excluded
          ? -1
          : _strongTotal.hasMatch(line)
              ? 3
              : _subTotal.hasMatch(line)
                  ? 1
                  : _plainTotal.hasMatch(line)
                      ? 2
                      : 0;

      for (final token in _tokensIn(line)) {
        // A bare integer only counts as money when the line gives it context.
        if (!token.looksLikeMoney && score <= 0) continue;
        final minor = token.minor;
        if (minor == null || minor <= 0) continue;
        allAmounts.add(minor);
        if (isTax) taxMinor ??= minor;
        // `>=` so a later "GRAND TOTAL" supersedes an earlier "TOTAL" of the
        // same tier — the final tally is always the one printed last.
        if (score > 0 && score >= totalScore) {
          totalScore = score;
          totalMinor = minor;
        }
      }
    }

    var totalConfidence = switch (totalScore) {
      3 => 0.9,
      2 => 0.85,
      1 => 0.6, // only a subtotal was found
      _ => 0.0,
    };
    if (totalMinor == null && allAmounts.isNotEmpty) {
      totalMinor = allAmounts.reduce((a, b) => a > b ? a : b);
      totalConfidence = 0.5; // heuristic: largest printed amount
    }

    // ── Date: prefer a line that labels itself as the date ────────────────
    DateTime? date;
    var dateConfidence = 0.0;
    for (final line in trimmed) {
      final parsed = _parseDate(line);
      if (parsed == null) continue;
      final labelled = _dateKeyword.hasMatch(line);
      if (date == null) {
        date = parsed;
        dateConfidence = labelled ? 0.9 : 0.75;
      }
      if (labelled) {
        date = parsed;
        dateConfidence = 0.9;
        break;
      }
    }

    // ── Payment method ────────────────────────────────────────────────────
    String? paymentMethod;
    for (final e in _paymentMethods.entries) {
      if (e.key.hasMatch(joined)) {
        paymentMethod = e.value;
        break;
      }
    }

    // ── Receipt number and vendor contact ─────────────────────────────────
    String? receiptNumber;
    String? merchantPhone;
    for (final line in trimmed) {
      // A date is also digits behind a label, so never let it become the
      // receipt number.
      if (receiptNumber == null && _parseDate(line) == null) {
        final m = _receiptNumber.firstMatch(line);
        final candidate = m?.group(1);
        if (candidate != null && candidate.length >= 3) {
          receiptNumber = candidate.toUpperCase();
        }
      }
      if (merchantPhone == null) {
        final p = _phone.firstMatch(line)?.group(1)?.trim();
        // Strip formatting to count real digits before accepting it.
        if (p != null && p.replaceAll(RegExp(r'\D'), '').length >= 7) {
          merchantPhone = p;
        }
      }
      if (receiptNumber != null && merchantPhone != null) break;
    }

    // ── Line items: description + trailing amount ─────────────────────────
    final items = <ReceiptLineItem>[];
    for (final line in trimmed) {
      if (_plainTotal.hasMatch(line) ||
          _strongTotal.hasMatch(line) ||
          _subTotal.hasMatch(line) ||
          _taxKeywords.hasMatch(line) ||
          _notATotal.hasMatch(line) ||
          // "VISA CARD  5,000.00" is how the bill was settled, not something
          // that was bought.
          _paymentMethods.keys.any((r) => r.hasMatch(line))) {
        continue;
      }
      final token = _tokensIn(line).where((t) => t.looksLikeMoney).firstOrNull;
      if (token == null) continue;
      final desc = line.substring(0, token.start).trim();
      final minor = token.minor;
      if (desc.length >= 3 &&
          minor != null &&
          minor > 0 &&
          minor != totalMinor) {
        items.add(ReceiptLineItem(_titleCase(desc), minor));
      }
    }

    return ParsedReceipt(
      merchant: merchant,
      merchantConfidence: merchantConfidence,
      totalMinor: totalMinor,
      totalConfidence: totalConfidence,
      taxMinor: taxMinor,
      date: date,
      dateConfidence: dateConfidence,
      currency: currency,
      paymentMethod: paymentMethod,
      receiptNumber: receiptNumber,
      merchantPhone: merchantPhone,
      lineItems: items.take(30).toList(),
    );
  }

  static Iterable<_MoneyToken> _tokensIn(String line) =>
      _money.allMatches(line).map(_MoneyToken.new);

  // ── Dates ───────────────────────────────────────────────────────────────

  static DateTime? _parseDate(String line) {
    for (final candidate in [
      _isoDate(line),
      _monthNameDate(line),
      _numericDate(line),
    ]) {
      if (candidate != null && _plausible(candidate)) return candidate;
    }
    return null;
  }

  /// yyyy-mm-dd / yyyy.mm.dd / yyyy/mm/dd
  static final _iso =
      RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');

  static DateTime? _isoDate(String line) {
    final m = _iso.firstMatch(line);
    if (m == null) return null;
    return _build(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  /// "12 Aug 2026", "12-AUG-26", "Aug 12, 2026"
  static final _dayMonthName = RegExp(
      r'(?<!\d)(\d{1,2})[\s\-/.]*([a-z]{3,9})[\s\-/.,]*(\d{2,4})(?!\d)',
      caseSensitive: false);
  static final _monthNameDay = RegExp(
      r'([a-z]{3,9})[\s\-/.]+(\d{1,2})(?:st|nd|rd|th)?[\s\-/.,]+(\d{2,4})(?!\d)',
      caseSensitive: false);

  static DateTime? _monthNameDate(String line) {
    final dmy = _dayMonthName.firstMatch(line);
    if (dmy != null) {
      final month = _monthFromName(dmy.group(2)!);
      if (month != null) {
        return _build(_expandYear(int.parse(dmy.group(3)!)), month,
            int.parse(dmy.group(1)!));
      }
    }
    final mdy = _monthNameDay.firstMatch(line);
    if (mdy != null) {
      final month = _monthFromName(mdy.group(1)!);
      if (month != null) {
        return _build(_expandYear(int.parse(mdy.group(3)!)), month,
            int.parse(mdy.group(2)!));
      }
    }
    return null;
  }

  static int? _monthFromName(String raw) {
    final key = raw.toLowerCase();
    if (key.length < 3) return null;
    return _months[key.substring(0, 3)];
  }

  /// dd/mm/yyyy, mm/dd/yyyy and their two-digit-year variants.
  ///
  /// Day-first is the default because it is what Sri Lankan (and most
  /// non-US) receipts print, but a first component above 12 proves day-first
  /// and a second component above 12 proves month-first. The old code simply
  /// gave up on the latter, so US-formatted receipts produced no date at all.
  static final _numeric =
      RegExp(r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?!\d)');

  static DateTime? _numericDate(String line) {
    final m = _numeric.firstMatch(line);
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final year = _expandYear(int.parse(m.group(3)!));
    final (day, month) = (a > 12 && b <= 12)
        ? (a, b)
        : (b > 12 && a <= 12)
            ? (b, a)
            : (a, b); // ambiguous → day-first
    return _build(year, month, day);
  }

  /// Two-digit years are always this century on a receipt.
  static int _expandYear(int y) => y >= 100 ? y : 2000 + y;

  /// Rejects impossible component combinations instead of letting
  /// [DateTime]'s roll-over silently invent a date (month 13 → next January).
  static DateTime? _build(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null; // e.g. 31 February
    return d;
  }

  static bool _plausible(DateTime d) {
    final now = DateTime.now();
    return d.isAfter(now.subtract(const Duration(days: 3 * 365))) &&
        d.isBefore(now.add(const Duration(days: 2)));
  }

  static String _titleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// A money-shaped regex hit, plus the judgement of whether it really is money.
class _MoneyToken {
  _MoneyToken(this._match);
  final RegExpMatch _match;

  int get start => _match.start;
  String? get _currency => _match.group(1);
  String get _integer => _match.group(2)!;
  String? get _decimals => _match.group(3);
  String? get _slashSuffix => _match.group(4);

  /// A bare integer with no decimals, no currency mark, no thousands
  /// separator and no "/-" is far more likely to be a quantity, a year or
  /// part of a reference number than a price.
  bool get looksLikeMoney =>
      _decimals != null ||
      _currency != null ||
      _slashSuffix != null ||
      _integer.contains(',');

  int? get minor {
    final major = int.tryParse(_integer.replaceAll(',', ''));
    if (major == null || major > ReceiptParser._maxPlausibleMajor) return null;
    final cents =
        _decimals == null ? 0 : int.parse(_decimals!.padRight(2, '0'));
    return major * 100 + cents;
  }
}
