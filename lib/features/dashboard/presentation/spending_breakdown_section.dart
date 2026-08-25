import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/period.dart';
import '../../transactions/presentation/granularity_bar.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'spending_donut.dart';

/// The period selected for the Home spending breakdown. Lives at app scope so
/// the choice survives tab switches for the whole session.
final breakdownPeriodProvider = StateProvider<Period>(
  (_) => Period.containing(DateTime.now(), PeriodGranularity.month),
);

/// Aggregated totals for the selected breakdown period — persisted
/// transactions only, recomputed whenever data or the period changes.
final breakdownTotalsProvider = Provider<PeriodTotals>((ref) {
  final txs =
      ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
  final period = ref.watch(breakdownPeriodProvider);
  return PeriodTotals.compute(txs, period);
});

/// Home "Spending breakdown" with Day / Week / Month / Year filtering,
/// previous/next period navigation and a clear range label.
class SpendingBreakdownSection extends ConsumerWidget {
  const SpendingBreakdownSection({super.key, required this.categories, required this.currency});

  final Map<String, Category> categories;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(breakdownPeriodProvider);
    final totals = ref.watch(breakdownTotalsProvider);

    void setPeriod(Period p) =>
        ref.read(breakdownPeriodProvider.notifier).state = p;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Granularity filter — compact segmented control.
        GranularityBar(
          selected: period.granularity,
          onChanged: (g) => setPeriod(Period.containing(DateTime.now(), g)),
        ),
        const SizedBox(height: FgTokens.s2),
        // Period navigation + current range label + period total.
        Row(children: [
          IconButton(
            tooltip: 'Previous ${period.granularity.label.toLowerCase()}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setPeriod(period.previous()),
          ),
          Expanded(
            child: Column(children: [
              Text(period.label(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                'Spent ${Money(totals.expenseMinor, currency).format()}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Next ${period.granularity.label.toLowerCase()}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            // Never navigate into the future beyond the current period.
            onPressed: period.isCurrent || period.start.isAfter(DateTime.now())
                ? null
                : () => setPeriod(period.next()),
          ),
        ]),
        const SizedBox(height: FgTokens.s2),
        SpendingDonut(
          byCategory: totals.byCategory,
          categories: categories,
          currency: currency,
        ),
      ],
    );
  }
}
