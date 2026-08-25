import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/cards.dart';
import '../../accounts/domain/account.dart';
import '../../insights/domain/categorizer.dart';
import '../../insights/domain/duplicate_detector.dart';
import '../domain/category.dart';
import '../domain/transaction_entry.dart';
import 'transaction_providers.dart';
import 'voice_entry_sheet.dart';

/// Add/edit income or expense with live category suggestion, duplicate check
/// before save, and voice entry. Works fully offline (queued sync).
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.initialType, this.prefill, this.editTx});

  final String? initialType; // 'income' | 'expense'
  final TransactionEntry? prefill; // from OCR/voice review
  final TransactionEntry? editTx;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  /// Stable id for the auto-created first account, so repeated saves reuse
  /// the same document instead of multiplying "Cash" accounts.
  static const _kDefaultCashId = 'acc_cash_default';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  late TxType _type;
  String? _categoryId;
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _busy = false;
  CategorySuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    final seed = widget.editTx ?? widget.prefill;
    _type = seed?.type ??
        (widget.initialType == 'income' ? TxType.income : TxType.expense);
    _amount = TextEditingController(
        text: seed == null ? '' : (seed.amountMinor / 100).toStringAsFixed(2));
    _merchant = TextEditingController(text: seed?.merchant ?? '');
    _note = TextEditingController(text: seed?.note ?? '');
    _categoryId = seed?.categoryId;
    _accountId = seed?.accountId.isEmpty ?? true ? null : seed?.accountId;
    _date = seed?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  void _suggestCategory() {
    if (_type != TxType.expense || _merchant.text.trim().isEmpty) return;
    final s = Categorizer().suggest(_merchant.text, note: _note.text);
    if (s.categoryId != 'other' || _categoryId == null) {
      setState(() {
        _suggestion = s;
        _categoryId ??= s.categoryId;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(transactionsRepoProvider);
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    if (repo == null) return;
    final currency = ref.read(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';
    if (_accountId == null && accounts.isNotEmpty) _accountId = accounts.first.id;
    if (_accountId == null || (accounts.isEmpty && _accountId == _kDefaultCashId)) {
      // First transaction with no accounts yet: create a default Cash
      // account on the fly so the user is never blocked.
      await ref.read(accountsRepoProvider)?.upsert(
            Account(
              id: _kDefaultCashId,
              name: 'Cash',
              type: AccountType.cash,
              balanceMinor: 0,
              currency: currency,
            ),
            docId: _kDefaultCashId,
          );
      _accountId = _kDefaultCashId;
    }
    final minor = Money.tryParseToMinor(_amount.text, currency: currency)!;

    final entry = TransactionEntry(
      id: widget.editTx?.id ?? const Uuid().v4(),
      clientId: widget.editTx?.clientId ?? const Uuid().v4(),
      type: _type,
      amountMinor: minor,
      currency: currency,
      categoryId: _categoryId ?? (_type == TxType.income ? 'other_income' : 'other'),
      accountId: _accountId!,
      occurredAt: _date,
      merchant: _merchant.text.trim(),
      note: _note.text.trim(),
      receiptId: widget.prefill?.receiptId,
      source: widget.prefill?.source ?? TxSource.manual,
      categoryConfidence: _suggestion?.confidence,
    );

    // Duplicate check against recent transactions before committing.
    if (widget.editTx == null) {
      final recent = ref.read(transactionsStreamProvider).valueOrNull ?? [];
      final dups = const DuplicateDetector().check(entry, recent.take(100));
      if (dups.isNotEmpty && mounted) {
        final proceed = await showConfirmSheet(
          context,
          title: 'Possible duplicate',
          message:
              'This looks like "${dups.first.existing.merchant.isEmpty ? 'a recent transaction' : dups.first.existing.merchant}" '
              '(${dups.first.reasons.join(', ').toLowerCase()}). Save anyway?',
          confirmLabel: 'Save anyway',
        );
        if (!proceed) return;
      }
    }

    setState(() => _busy = true);
    await repo.upsert(entry, docId: entry.id);

    // Adjust the account balance so Net Worth and Account Balance update correctly
    final accountsRepo = ref.read(accountsRepoProvider);
    if (accountsRepo != null) {
      final currentAccount = accounts.where((a) => a.id == _accountId).firstOrNull ??
          await accountsRepo.getById(_accountId!);
      if (currentAccount != null) {
        var diff = entry.signedMinor;
        if (widget.editTx != null && widget.editTx!.accountId == _accountId) {
          diff -= widget.editTx!.signedMinor;
        } else if (widget.editTx != null && widget.editTx!.accountId != _accountId) {
          // Revert old account balance if account was changed
          final oldAcc = accounts.where((a) => a.id == widget.editTx!.accountId).firstOrNull ??
              await accountsRepo.getById(widget.editTx!.accountId);
          if (oldAcc != null) {
            await accountsRepo.upsert(
              oldAcc.copyWith(balanceMinor: oldAcc.balanceMinor - widget.editTx!.signedMinor),
              docId: oldAcc.id,
            );
          }
        }
        await accountsRepo.upsert(
          currentAccount.copyWith(balanceMinor: currentAccount.balanceMinor + diff),
          docId: currentAccount.id,
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_type == TxType.income ? 'Income saved' : 'Expense saved')),
    );
    context.pop();
  }

  /// Quick account creation without leaving the expense form.
  Future<void> _createAccount(BuildContext context) async {
    final name = TextEditingController(text: 'Cash wallet');
    final balance = TextEditingController(text: '0');
    var type = AccountType.cash;
    final formKey = GlobalKey<FormState>();
    final currency = ref.read(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: FgTokens.s6, right: FgTokens.s6, top: FgTokens.s6,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + FgTokens.s6,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New account', style: Theme.of(sheetContext).textTheme.titleLarge),
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
                    items: const [
                      DropdownMenuItem(value: AccountType.cash, child: Text('Cash')),
                      DropdownMenuItem(value: AccountType.bank, child: Text('Bank account')),
                      DropdownMenuItem(value: AccountType.card, child: Text('Card')),
                      DropdownMenuItem(value: AccountType.wallet, child: Text('Mobile wallet')),
                      DropdownMenuItem(value: AccountType.savings, child: Text('Savings')),
                    ],
                    onChanged: (v) => setSheetState(() => type = v ?? type),
                  ),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: balance,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Current balance'),
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final repo = ref.read(accountsRepoProvider);
                      if (repo == null) return;
                      final id = await repo.upsert(Account(
                        id: '',
                        name: name.text.trim(),
                        type: type,
                        balanceMinor:
                            Money.tryParseToMinor(balance.text, currency: currency) ?? 0,
                        currency: currency,
                      ));
                      if (mounted) setState(() => _accountId = id);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = (ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds)
        .where((c) => c.kind == _type && c.id != 'transfer')
        .toList();
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    // Auto-pick when there is exactly one account (or the current pick vanished).
    if (accounts.isNotEmpty && !accounts.any((a) => a.id == _accountId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _accountId = accounts.first.id);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editTx != null
            ? 'Edit transaction'
            : _type == TxType.income
                ? 'Add income'
                : 'Add expense'),
        actions: [
          IconButton(
            tooltip: 'Add by voice',
            icon: const Icon(Icons.mic_none),
            onPressed: () async {
              final result = await showVoiceEntrySheet(context);
              if (result != null && mounted) {
                _merchant.text = result.merchant ?? _merchant.text;
                if (result.amountMinor != null) {
                  _amount.text = (result.amountMinor! / 100).toStringAsFixed(2);
                }
                _suggestCategory();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(FgTokens.s4),
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TxType>(
                  segments: const [
                    ButtonSegment(
                        value: TxType.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(
                        value: TxType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _categoryId = null;
                  }),
                ),
              ),
              const SizedBox(height: FgTokens.s5),
              // Amount is the hero of this form — large, centred, on its own
              // surface. Same controller and validator as before.
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: FgTokens.s4, vertical: FgTokens.s5),
                  child: Column(
                    children: [
                      Text(
                        _type == TxType.income ? 'Amount received' : 'Amount spent',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: FgTokens.s2),
                      TextFormField(
                        controller: _amount,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: _type == TxType.income
                              ? FgTokens.success
                              : theme.colorScheme.onSurface,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: Validators.amount,
                        autofocus:
                            widget.prefill == null && widget.editTx == null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FgTokens.s4),
              TextFormField(
                controller: _merchant,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Merchant / payer', prefixIcon: Icon(Icons.storefront_outlined)),
                onChanged: (_) => _suggestCategory(),
              ),
              if (_suggestion != null && _type == TxType.expense) ...[
                const SizedBox(height: FgTokens.s2),
                Semantics(
                  label: 'Suggested category ${_suggestion!.categoryId} with '
                      '${(_suggestion!.confidence * 100).round()} percent confidence',
                  child: Wrap(spacing: FgTokens.s2, children: [
                    Chip(
                      avatar: const Icon(Icons.auto_awesome, size: FgTokens.iconSm),
                      label: Text(
                          'Suggested: ${_suggestion!.categoryId} · ${(_suggestion!.confidence * 100).round()}%'),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: FgTokens.s4),
              DropdownButtonFormField<String>(
                value: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
              const SizedBox(height: FgTokens.s4),
              DropdownButtonFormField<String>(
                // A receipt cannot know which account paid, so the OCR prefill
                // arrives with an empty accountId that initState turns into
                // null. `_save` already falls back to the first account in that
                // case — but `validate()` runs first, so "Choose an account"
                // fired and a scanned bill could never be saved at all.
                //
                // Defaulting is limited to prefilled entries: the manual flow
                // keeps asking for an explicit choice, exactly as before.
                value: accounts.isEmpty
                    ? _kDefaultCashId
                    : (accounts.any((a) => a.id == _accountId)
                        ? _accountId
                        : (widget.prefill != null && _accountId == null
                            ? accounts.first.id
                            : null)),
                decoration: const InputDecoration(
                    labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                items: [
                  // No accounts yet: offer a default that is created on save,
                  // so a brand-new user is never blocked here.
                  if (accounts.isEmpty)
                    const DropdownMenuItem(
                        value: _kDefaultCashId,
                        child: Text('Cash (created automatically)')),
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Choose an account' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _createAccount(context),
                  icon: const Icon(Icons.add, size: FgTokens.iconSm),
                  label: const Text('New account'),
                ),
              ),
              const SizedBox(height: FgTokens.s4),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FgTokens.rMd)),
                tileColor: theme.colorScheme.surfaceContainer,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date'),
                subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: FgTokens.s4),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_outlined)),
              ),
              const SizedBox(height: FgTokens.s6),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.editTx != null ? 'Save changes' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
