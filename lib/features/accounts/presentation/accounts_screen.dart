import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/fintech.dart';
import '../../../core/widgets/states.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/account.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final currency =
        ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref, currency: currency),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: AsyncValueView(
        value: accountsAsync,
        onRetry: () => ref.invalidate(accountsStreamProvider),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message:
                  'Add your cash, bank or wallet accounts to track balances and net worth.',
              actionLabel: 'Add account',
              onAction: () => _showEditor(context, ref, currency: currency),
            );
          }
          // Net worth across every account — derived, same maths as the
          // dashboard hero.
          final netWorth = accounts.fold<int>(0, (s, a) => s + a.balanceMinor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                FgTokens.s4, FgTokens.s2, FgTokens.s4, 96),
            children: [
              BalanceHeroCard(
                label: 'Total across ${accounts.length} '
                    '${accounts.length == 1 ? 'account' : 'accounts'}',
                amount: AmountText(Money(netWorth, currency)),
              ),
              const FinSectionHeader('Your accounts'),
              RowGroup(children: [
                for (final a in accounts)
                  FinListRow(
                    icon: _iconFor(a.type),
                    title: a.name,
                    subtitle: _labelFor(a.type),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountDetailScreen(accountId: a.id),
                      ),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      AmountText(Money(a.balanceMinor, a.currency),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: 'Edit account',
                        icon: const Icon(Icons.edit_outlined,
                            size: FgTokens.iconMd),
                        onPressed: () => _showEditor(context, ref,
                            existing: a, currency: currency),
                      ),
                    ]),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }

  static IconData _iconFor(AccountType t) => switch (t) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.card => Icons.credit_card_outlined,
        AccountType.wallet => Icons.smartphone_outlined,
        AccountType.savings => Icons.savings_outlined,
      };

  static String _labelFor(AccountType t) => switch (t) {
        AccountType.cash => 'Cash',
        AccountType.bank => 'Bank account',
        AccountType.card => 'Card',
        AccountType.wallet => 'Mobile wallet',
        AccountType.savings => 'Savings',
      };

  void _showEditor(BuildContext context, WidgetRef ref,
      {Account? existing, required String currency}) {
    final name = TextEditingController(text: existing?.name ?? '');
    final balance = TextEditingController(
        text: existing == null
            ? ''
            : (existing.balanceMinor / 100).toStringAsFixed(2));
    var type = existing?.type ?? AccountType.bank;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: FgTokens.s6,
              right: FgTokens.s6,
              top: FgTokens.s6,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom + FgTokens.s6,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'Add account' : 'Edit account',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  DropdownButtonFormField<AccountType>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final t in AccountType.values)
                        DropdownMenuItem(value: t, child: Text(_labelFor(t))),
                    ],
                    onChanged: (v) => setSheetState(() => type = v ?? type),
                  ),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: balance,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration:
                        const InputDecoration(labelText: 'Current balance'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Balance is required'
                        : null,
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final repo = ref.read(accountsRepoProvider);
                      if (repo == null) return;
                      final minor = Money.tryParseToMinor(balance.text,
                              currency: currency) ??
                          0;
                      final account = Account(
                        id: existing?.id ?? '',
                        name: name.text.trim(),
                        type: type,
                        balanceMinor: minor,
                        currency: currency,
                      );
                      await repo.upsert(account, docId: existing?.id);
                      if (sheetContext.mounted)
                        Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Save'),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: FgTokens.s2),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(sheetContext).colorScheme.error),
                      onPressed: () async {
                        final confirmed = await showConfirmSheet(
                          sheetContext,
                          title: 'Archive this account?',
                          message:
                              'Its transactions stay; the account is hidden from lists.',
                          confirmLabel: 'Archive',
                          destructive: true,
                        );
                        if (confirmed) {
                          await ref.read(accountsRepoProvider)?.upsert(
                              existing.copyWith(archived: true),
                              docId: existing.id);
                          if (sheetContext.mounted)
                            Navigator.of(sheetContext).pop();
                        }
                      },
                      child: const Text('Archive account'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
