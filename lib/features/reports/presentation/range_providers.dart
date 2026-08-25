import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/range_selector.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Currently selected chart range (shared by Reports).
final chartRangeProvider = StateProvider<ChartRange>((_) => ChartRange.month);

class SeriesPoint {
  const SeriesPoint(this.bucket, this.incomeMinor, this.expenseMinor);
  final String bucket;
  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
}

/// Income/expense series bucketed by the selected range (oldest first).
/// Transfers are excluded — moving your own money isn't income or spending.
final rangeSeriesProvider = Provider<List<SeriesPoint>>((ref) {
  final range = ref.watch(chartRangeProvider);
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
  final from = range.start();
  final relevant =
      txs.where((t) => t.categoryId != 'transfer' && !t.occurredAt.isBefore(from));
  final byBucket = groupBy(relevant, (TransactionEntry t) => range.bucketOf(t.occurredAt));
  final keys = byBucket.keys.toList()..sort();
  return [
    for (final k in keys)
      SeriesPoint(
        k,
        byBucket[k]!.where((t) => t.type == TxType.income).fold(0, (s, t) => s + t.amountMinor),
        byBucket[k]!.where((t) => t.type == TxType.expense).fold(0, (s, t) => s + t.amountMinor),
      ),
  ];
});
