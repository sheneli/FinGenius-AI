import 'package:collection/collection.dart';

import '../../transactions/domain/transaction_entry.dart';
import 'merchant_normalizer.dart';

/// Detects recurring merchant patterns (subscriptions). Requirements:
/// ≥ 3 occurrences of a normalised merchant, near-regular interval
/// (weekly/monthly/yearly ±20%), amounts within ±15% of the median.
/// Candidates are surfaced for the user to confirm or dismiss — never
/// auto-committed.
class SubscriptionCandidate {
  const SubscriptionCandidate({
    required this.merchant,
    required this.normalizedMerchant,
    required this.amountMinor,
    required this.intervalDays,
    required this.confidence,
    required this.evidenceTxIds,
    required this.nextExpected,
  });
  final String merchant;
  final String normalizedMerchant;
  final int amountMinor; // median
  final int intervalDays;
  final double confidence;
  final List<String> evidenceTxIds;
  final DateTime nextExpected;
}

class SubscriptionDetector {
  const SubscriptionDetector({this.minOccurrences = 3, this.amountTolerance = 0.15, this.intervalTolerance = 0.20});
  final int minOccurrences;
  final double amountTolerance;
  final double intervalTolerance;

  static const _canonicalIntervals = [7, 14, 30, 365];

  List<SubscriptionCandidate> detect(Iterable<TransactionEntry> transactions) {
    final expenses = transactions.where((t) => t.type == TxType.expense && t.merchant.trim().isNotEmpty);
    final byMerchant = groupBy(expenses, (TransactionEntry t) => MerchantNormalizer.normalize(t.merchant));
    final out = <SubscriptionCandidate>[];

    byMerchant.forEach((normalized, txs) {
      if (normalized.isEmpty || txs.length < minOccurrences) return;
      txs.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

      final amounts = txs.map((t) => t.amountMinor).toList()..sort();
      final median = amounts[amounts.length ~/ 2];
      if (median <= 0) return;
      final similarAmount = txs.where((t) => (t.amountMinor - median).abs() / median <= amountTolerance).toList();
      if (similarAmount.length < minOccurrences) return;

      final gaps = <int>[];
      for (var i = 1; i < similarAmount.length; i++) {
        gaps.add(similarAmount[i].occurredAt.difference(similarAmount[i - 1].occurredAt).inDays);
      }
      if (gaps.isEmpty) return;
      final meanGap = gaps.reduce((a, b) => a + b) / gaps.length;
      if (meanGap < 5) return; // daily coffee is a habit, not a subscription

      final canonical = _canonicalIntervals
          .map((c) => (c, (meanGap - c).abs() / c))
          .reduce((a, b) => a.$2 < b.$2 ? a : b);
      if (canonical.$2 > intervalTolerance) return;

      final regularGaps = gaps.where((g) => (g - meanGap).abs() / meanGap <= intervalTolerance).length;
      final regularity = regularGaps / gaps.length;
      if (regularity < 0.5) return;

      // Confidence: occurrences (up to 0.4) + regularity (up to 0.4) + interval fit (up to 0.2)
      final confidence = ((similarAmount.length / 6).clamp(0.0, 1.0) * 0.4) +
          (regularity * 0.4) +
          ((1 - canonical.$2 / intervalTolerance).clamp(0.0, 1.0) * 0.2);

      out.add(SubscriptionCandidate(
        merchant: similarAmount.last.merchant,
        normalizedMerchant: normalized,
        amountMinor: median,
        intervalDays: canonical.$1,
        confidence: double.parse(confidence.toStringAsFixed(2)),
        evidenceTxIds: similarAmount.map((t) => t.id).take(12).toList(),
        nextExpected: similarAmount.last.occurredAt.add(Duration(days: canonical.$1)),
      ));
    });

    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return out;
  }
}
