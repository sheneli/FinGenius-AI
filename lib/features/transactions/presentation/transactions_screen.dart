import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/fintech.dart';
import '../../../core/widgets/states.dart';
import '../domain/category.dart';
import '../domain/transaction_entry.dart';
import 'transaction_providers.dart';
import 'transaction_tile.dart';

/// Activity — the full transaction history.
///
/// v3 presentation: search + segmented filters over a date-grouped list with
/// a live totals strip. Filtering, searching, refresh and navigation are the
/// same logic as before; only the layout changed.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'all'; // all | income | expense
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(transactionsStreamProvider);
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds;
    final catById = {for (final c in categories) c.id: c};
    final currency =
        ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          SquareIconButton(
            icon: Icons.document_scanner_outlined,
            tooltip: 'Scan a receipt',
            onPressed: () => context.go('/transactions/scan'),
          ),
          const SizedBox(width: FgTokens.s4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                FgTokens.s4, 0, FgTokens.s4, FgTokens.s3),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search merchant or note',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FgTokens.s4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'expense', label: Text('Expenses')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          const SizedBox(height: FgTokens.s3),
          Expanded(
            child: AsyncValueView(
              value: txsAsync,
              onRetry: () => ref.invalidate(transactionsStreamProvider),
              data: (txs) {
                final filtered = txs.where((t) {
                  if (_filter == 'income' && t.type != TxType.income) return false;
                  if (_filter == 'expense' && t.type != TxType.expense) return false;
                  if (_query.isNotEmpty &&
                      !t.merchant.toLowerCase().contains(_query) &&
                      !t.note.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _query.isEmpty ? 'No transactions yet' : 'No matches',
                    message: _query.isEmpty
                        ? 'Add your first income or expense — or scan a receipt.'
                        : 'Try a different search or filter.',
                    actionLabel: _query.isEmpty ? 'Add transaction' : null,
                    onAction:
                        _query.isEmpty ? () => context.go('/transactions/add') : null,
                  );
                }

                // Totals for exactly what is on screen — derived, never stored.
                final shownIn = filtered
                    .where((t) => t.type == TxType.income)
                    .fold<int>(0, (s, t) => s + t.amountMinor);
                final shownOut = filtered
                    .where((t) => t.type == TxType.expense)
                    .fold<int>(0, (s, t) => s + t.amountMinor);

                // Group by calendar day, newest first (list is already sorted).
                final byDay = groupBy<TransactionEntry, DateTime>(
                  filtered,
                  (t) => DateTime(
                      t.occurredAt.year, t.occurredAt.month, t.occurredAt.day),
                );
                final days = byDay.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transactionsStreamProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        FgTokens.s4, 0, FgTokens.s4, 96),
                    children: [
                      _TotalsStrip(
                        count: filtered.length,
                        inMinor: shownIn,
                        outMinor: shownOut,
                        currency: currency,
                      ),
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              FgTokens.s2, FgTokens.s5, FgTokens.s2, FgTokens.s2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  Dates.friendly(day),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                Money(
                                  byDay[day]!
                                      .fold<int>(0, (s, t) => s + t.signedMinor),
                                  currency,
                                ).format(compact: true),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        RowGroup(children: [
                          for (final tx in byDay[day]!)
                            TransactionTile(
                              tx: tx,
                              category: catById[tx.categoryId],
                              onTap: () => context.go('/transactions/${tx.id}'),
                            ),
                        ]),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Money in / money out for the current filter + search selection.
class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({
    required this.count,
    required this.inMinor,
    required this.outMinor,
    required this.currency,
  });

  final int count;
  final int inMinor;
  final int outMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, int minor, Color color, IconData icon) => Expanded(
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(FgTokens.rSm),
              ),
              child: Icon(icon, size: FgTokens.iconSm, color: color),
            ),
            const SizedBox(width: FgTokens.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money(minor, currency).format(compact: true),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        );

    return Semantics(
      container: true,
      label: '$count transactions shown. In ${Money(inMinor, currency).format()}, '
          'out ${Money(outMinor, currency).format()}.',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(FgTokens.s4),
            child: Row(children: [
              cell('Money in', inMinor, FgTokens.success, Icons.south_west),
              const SizedBox(width: FgTokens.s3),
              cell('Money out', outMinor, FgTokens.error, Icons.north_east),
            ]),
          ),
        ),
      ),
    );
  }
}
