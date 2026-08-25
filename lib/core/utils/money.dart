import 'package:intl/intl.dart';

/// Money value object. Amounts are integer minor units (e.g. cents) —
/// floating point is never used for arithmetic, only for display scaling.
class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);
  const Money.zero([this.currency = 'LKR']) : minor = 0;

  final int minor;
  final String currency; // ISO 4217

  static const Map<String, int> _decimals = {
    'LKR': 2, 'USD': 2, 'GBP': 2, 'EUR': 2, 'INR': 2, 'AUD': 2, 'JPY': 0,
  };

  int get decimals => _decimals[currency] ?? 2;
  double get asDouble => minor / _pow10(decimals);

  Money operator +(Money other) => _sameCurrency(other, () => Money(minor + other.minor, currency));
  Money operator -(Money other) => _sameCurrency(other, () => Money(minor - other.minor, currency));
  Money scale(num factor) => Money((minor * factor).round(), currency);
  bool get isNegative => minor < 0;
  Money abs() => Money(minor.abs(), currency);

  Money _sameCurrency(Money other, Money Function() op) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
    return op();
  }

  String format({bool compact = false, bool withSymbol = true}) {
    final symbol = withSymbol ? _symbol : '';
    if (compact && minor.abs() >= 1000000 * _pow10(decimals)) {
      return '$symbol${(asDouble / 1000000).toStringAsFixed(1)}M';
    }
    if (compact && minor.abs() >= 100000 * _pow10(decimals)) {
      return '$symbol${(asDouble / 1000).toStringAsFixed(0)}K';
    }
    final f = NumberFormat.currency(symbol: symbol, decimalDigits: decimals);
    return f.format(asDouble);
  }

  String get _symbol => switch (currency) {
        'LKR' => 'Rs ',
        'USD' => r'$',
        'GBP' => '£',
        'EUR' => '€',
        'INR' => '₹',
        'JPY' => '¥',
        _ => '$currency ',
      };

  static int _pow10(int n) => switch (n) { 0 => 1, 1 => 10, 2 => 100, _ => 1000 };

  /// Parses user input like "1,250.50" into minor units.
  static int? tryParseToMinor(String input, {String currency = 'LKR'}) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.\-]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    final d = _decimals[currency] ?? 2;
    return (value * _pow10(d)).round();
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);
  @override
  bool operator ==(Object other) => other is Money && other.minor == minor && other.currency == currency;
  @override
  int get hashCode => Object.hash(minor, currency);
  @override
  String toString() => format();
}
