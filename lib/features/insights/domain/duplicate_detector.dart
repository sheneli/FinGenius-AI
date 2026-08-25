import '../../transactions/domain/transaction_entry.dart';
import 'merchant_normalizer.dart';

/// Flags likely duplicate transactions before save. Signals compared:
/// amount (exact), account (exact), date/time proximity, merchant similarity,
/// note/reference text, and receipt fingerprint when available.
class DuplicateCandidate {
  const DuplicateCandidate(this.existing, this.score, this.reasons);
  final TransactionEntry existing;
  final double score; // 0..1
  final List<String> reasons;
}

class DuplicateDetector {
  const DuplicateDetector({this.threshold = 0.7, this.window = const Duration(hours: 48)});
  final double threshold;
  final Duration window;

  List<DuplicateCandidate> check(
    TransactionEntry candidate,
    Iterable<TransactionEntry> recent, {
    String? receiptFingerprint,
    String? Function(TransactionEntry tx)? existingFingerprintFor,
  }) {
    final out = <DuplicateCandidate>[];
    for (final tx in recent) {
      if (tx.id == candidate.id || tx.clientId == candidate.clientId) continue;
      if (tx.type != candidate.type) continue;

      final gap = tx.occurredAt.difference(candidate.occurredAt).abs();
      if (gap > window) continue;

      var score = 0.0;
      final reasons = <String>[];

      if (tx.amountMinor == candidate.amountMinor && tx.currency == candidate.currency) {
        score += 0.40;
        reasons.add('Same amount');
      } else {
        continue; // amount mismatch → not a duplicate under this policy
      }

      if (tx.accountId == candidate.accountId) {
        score += 0.15;
        reasons.add('Same account');
      }

      if (gap <= const Duration(minutes: 10)) {
        score += 0.20;
        reasons.add('Within minutes of each other');
      } else if (gap <= const Duration(hours: 24)) {
        score += 0.10;
        reasons.add('Same day');
      }

      final sim = MerchantNormalizer.similarity(tx.merchant, candidate.merchant);
      if (sim >= 0.8) {
        score += 0.20;
        reasons.add('Same merchant');
      } else if (sim >= 0.5) {
        score += 0.10;
        reasons.add('Similar merchant');
      }

      if (receiptFingerprint != null && existingFingerprintFor != null) {
        final fp = existingFingerprintFor(tx);
        if (fp != null && fp == receiptFingerprint) {
          score = 1.0;
          reasons.add('Identical receipt');
        }
      }

      if (score >= threshold) out.add(DuplicateCandidate(tx, score.clamp(0, 1), reasons));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }
}
