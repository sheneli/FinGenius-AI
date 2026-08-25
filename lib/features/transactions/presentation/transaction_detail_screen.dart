import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/states.dart';
import '../domain/category.dart';
import '../domain/transaction_entry.dart';
import 'add_transaction_screen.dart';
import 'transaction_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.txId});
  final String txId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txs = ref.watch(transactionsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: AsyncValueView(
        value: txs,
        onRetry: () => ref.invalidate(transactionsStreamProvider),
        data: (list) {
          final tx = list.where((t) => t.id == txId).firstOrNull;
          if (tx == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Not found',
              message: 'This transaction may have been deleted on another device.',
            );
          }
          final category = categories.where((c) => c.id == tx.categoryId).firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(FgTokens.s4),
            children: [
              GradientCard(
                child: Column(children: [
                  Text(tx.type == TxType.expense ? 'Expense' : 'Income',
                      style: theme.textTheme.labelLarge?.copyWith(color: FgTokens.gray)),
                  const SizedBox(height: FgTokens.s2),
                  AmountText(
                    Money(tx.signedMinor, tx.currency),
                    signed: true,
                    style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800, color: FgTokens.white),
                  ),
                  if (tx.pendingSync)
                    Padding(
                      padding: const EdgeInsets.only(top: FgTokens.s2),
                      child: Chip(
                        avatar: const Icon(Icons.sync, size: FgTokens.iconSm),
                        label: const Text('Waiting to sync'),
                        backgroundColor: FgTokens.warning.withValues(alpha: 0.2),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: FgTokens.s4),
              _row(context, 'Merchant / payer', tx.merchant.isEmpty ? '—' : tx.merchant),
              _row(context, 'Category', category?.name ?? tx.categoryId),
              _row(context, 'Date', Dates.full(tx.occurredAt)),
              _row(context, 'Source', switch (tx.source) {
                TxSource.ocr => 'Receipt scan',
                TxSource.voice => 'Voice entry',
                TxSource.recurring => 'Recurring bill',
                TxSource.manual => 'Manual entry',
              }),
              if (tx.note.isNotEmpty) _row(context, 'Note', tx.note),
              if (tx.receiptId != null) _row(context, 'Receipt', 'Attached (${tx.receiptId!.substring(0, 8)}…)'),
              const SizedBox(height: FgTokens.s6),
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddTransactionScreen(editTx: tx),
                  ),
                ),
              ),
              const SizedBox(height: FgTokens.s2),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                onPressed: () async {
                  final confirmed = await showConfirmSheet(
                    context,
                    title: 'Delete this transaction?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (confirmed) {
                    final accountsRepo = ref.read(accountsRepoProvider);
                    if (accountsRepo != null && tx.accountId.isNotEmpty) {
                      final acc = await accountsRepo.getById(tx.accountId);
                      if (acc != null) {
                        await accountsRepo.upsert(
                          acc.copyWith(balanceMinor: acc.balanceMinor - tx.signedMinor),
                          docId: acc.id,
                        );
                      }
                    }
                    await ref.read(transactionsRepoProvider)?.delete(tx.id);
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FgTokens.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
