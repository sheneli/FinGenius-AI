import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/states.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/transaction_tile.dart';
import '../domain/account.dart';

/// Account summary + full transaction history (searchable) + transfers.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
    final txsAsync = ref.watch(transactionsStreamProvider);
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds;
    final catById = {for (final c in categories) c.id: c};

    if (account == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Account not found',
          message: 'It may have been archived on another device.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: AsyncValueView(
        value: txsAsync,
        onRetry: () => ref.invalidate(transactionsStreamProvider),
        data: (txs) {
          final history = txs
              .where((t) => t.accountId == account.id)
              .where((t) =>
                  _query.isEmpty ||
                  t.merchant.toLowerCase().contains(_query) ||
                  t.note.toLowerCase().contains(_query))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(FgTokens.s4),
            children: [
              GradientCard(
                child: Column(children: [
                  Text(account.name,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: FgTokens.gray)),
                  const SizedBox(height: FgTokens.s2),
                  AmountText(
                    Money(account.balanceMinor, account.currency),
                    style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: FgTokens.white),
                  ),
                  const SizedBox(height: FgTokens.s4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.swap_horiz, size: FgTokens.iconSm),
                      label: const Text('Transfer'),
                      onPressed: accounts.length < 2
                          ? null
                          : () => showTransferSheet(context, ref,
                              from: account, accounts: accounts),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: FgTokens.s4),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search this account\'s history',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
              const SizedBox(height: FgTokens.s2),
              if (history.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions here yet',
                  message:
                      'Transactions using this account will appear in this history.',
                )
              else
                for (final tx in history)
                  TransactionTile(tx: tx, category: catById[tx.categoryId]),
            ],
          );
        },
      ),
    );
  }
}

/// Transfer between own accounts: adjusts both balances and records two
/// linked `transfer` transactions (excluded from income/expense analytics).
Future<void> showTransferSheet(
  BuildContext context,
  WidgetRef ref, {
  required Account from,
  required List<Account> accounts,
}) {
  final amount = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? toId = accounts.where((a) => a.id != from.id).firstOrNull?.id;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: FgTokens.s6,
            right: FgTokens.s6,
            top: FgTokens.s6,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + FgTokens.s6,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Transfer from ${from.name}',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: FgTokens.s4),
                DropdownButtonFormField<String>(
                  value: toId,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: [
                    for (final a in accounts.where((a) => a.id != from.id))
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setSheetState(() => toId = v),
                  validator: (v) =>
                      v == null ? 'Choose a destination account' : null,
                ),
                const SizedBox(height: FgTokens.s4),
                TextFormField(
                  controller: amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: Validators.amount,
                ),
                const SizedBox(height: FgTokens.s6),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || toId == null)
                      return;
                    final accountsRepo = ref.read(accountsRepoProvider);
                    final txRepo = ref.read(transactionsRepoProvider);
                    if (accountsRepo == null || txRepo == null) return;
                    final to = accounts.firstWhere((a) => a.id == toId);
                    final minor = Money.tryParseToMinor(amount.text,
                        currency: from.currency)!;
                    final now = DateTime.now();

                    await accountsRepo.upsert(
                        from.copyWith(balanceMinor: from.balanceMinor - minor),
                        docId: from.id);
                    await accountsRepo.upsert(
                        to.copyWith(balanceMinor: to.balanceMinor + minor),
                        docId: to.id);
                    final outLeg = TransactionEntry(
                      id: const Uuid().v4(),
                      clientId: const Uuid().v4(),
                      type: TxType.expense,
                      amountMinor: minor,
                      currency: from.currency,
                      categoryId: 'transfer',
                      accountId: from.id,
                      occurredAt: now,
                      merchant: 'Transfer to ${to.name}',
                    );
                    final inLeg = TransactionEntry(
                      id: const Uuid().v4(),
                      clientId: const Uuid().v4(),
                      type: TxType.income,
                      amountMinor: minor,
                      currency: from.currency,
                      categoryId: 'transfer',
                      accountId: to.id,
                      occurredAt: now,
                      merchant: 'Transfer from ${from.name}',
                    );
                    await txRepo.upsert(outLeg, docId: outLeg.id);
                    await txRepo.upsert(inLeg, docId: inLeg.id);

                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                          content: Text(
                              'Transferred ${Money(minor, from.currency).format()} to ${to.name}')));
                    }
                  },
                  child: const Text('Transfer'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
