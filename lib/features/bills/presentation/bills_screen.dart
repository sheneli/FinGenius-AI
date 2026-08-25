import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/states.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/bill.dart';
import 'bill_providers.dart';

/// Recurring bills with an interactive month calendar (tap a date to see the
/// bills due that day), mark-paid (records the expense), and overdue
/// highlighting. Recurrences are projected across month/year boundaries.
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  /// Bill ids with an in-flight mark-paid — prevents duplicate payments.
  final Set<String> _paying = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final billsAsync = ref.watch(billsStreamProvider);
    final currency = ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(title: const Text('Bills & calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, currency),
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
      body: AsyncValueView(
        value: billsAsync,
        onRetry: () => ref.invalidate(billsStreamProvider),
        data: (bills) {
          // Project every bill's recurrence into the displayed month.
          final occurrencesByDay = <int, List<Bill>>{};
          for (final b in bills) {
            for (final due in b.occurrencesInMonth(_month)) {
              occurrencesByDay.putIfAbsent(due.day, () => []).add(b);
            }
          }

          final selected = _selectedDay != null &&
                  _selectedDay!.year == _month.year &&
                  _selectedDay!.month == _month.month
              ? _selectedDay
              : null;
          final billsForSelected =
              selected == null ? null : (occurrencesByDay[selected.day] ?? const <Bill>[]);

          return ListView(
            padding: const EdgeInsets.fromLTRB(FgTokens.s4, FgTokens.s4, FgTokens.s4, 96),
            children: [
              // ── Interactive month calendar ──────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(FgTokens.s4),
                  child: Column(children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Previous month',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() {
                          _month = Dates.addMonths(_month, -1);
                          _selectedDay = null;
                        }),
                      ),
                      Expanded(
                        child: Text(Dates.monthLabel(Dates.periodKey(_month)),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() {
                          _month = Dates.addMonths(_month, 1);
                          _selectedDay = null;
                        }),
                      ),
                    ]),
                    _CalendarGrid(
                      month: _month,
                      markedDays: occurrencesByDay.keys.toSet(),
                      selectedDay: selected?.day,
                      onSelect: (day) => setState(() {
                        final tapped = DateTime(_month.year, _month.month, day);
                        // Tapping the selected day again clears the filter.
                        _selectedDay =
                            _selectedDay == tapped ? null : tapped;
                      }),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: FgTokens.s4),

              // ── Selected-day details ────────────────────────────────────
              if (selected != null) ...[
                Row(children: [
                  Expanded(
                    child: Text(
                      'Due on ${Dates.full(selected)}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedDay = null),
                    child: const Text('Show all'),
                  ),
                ]),
                if (billsForSelected!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: FgTokens.s4),
                    child: Text('Nothing due on this date.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  )
                else
                  for (final b in billsForSelected) _billCard(b, currency),
                const SizedBox(height: FgTokens.s4),
                Text('All bills',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: FgTokens.s2),
              ],

              // ── All bills ───────────────────────────────────────────────
              if (bills.isEmpty)
                EmptyState(
                  icon: Icons.event_outlined,
                  title: 'No recurring bills',
                  message: 'Add rent, utilities or subscriptions to get reminders before they are due.',
                  actionLabel: 'Add a bill',
                  onAction: () => _showEditor(context, currency),
                )
              else
                for (final b in bills) _billCard(b, currency),
            ],
          );
        },
      ),
    );
  }

  /// Overflow-proof bill card: identity row on top, amount + action on their
  /// own row below — nothing is squeezed into a height-limited trailing slot,
  /// so long names, small screens and large font scales all wrap safely.
  Widget _billCard(Bill b, String currency) {
    final theme = Theme.of(context);
    final busy = _paying.contains(b.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(FgTokens.s4, FgTokens.s3, FgTokens.s4, FgTokens.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    b.isOverdue ? Icons.warning_amber : Icons.event_repeat,
                    color: b.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                    size: FgTokens.iconMd,
                  ),
                ),
                const SizedBox(width: FgTokens.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${b.recurrence.name} · ${b.isOverdue ? 'overdue since' : 'due'} ${Dates.friendly(b.nextDueAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: b.isOverdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FgTokens.s2),
            Row(children: [
              Expanded(child: AmountText(Money(b.amountMinor, currency))),
              TextButton.icon(
                onPressed: busy ? null : () => _markPaid(b, currency),
                icon: busy
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: FgTokens.iconSm),
                label: Text(busy ? 'Saving…' : 'Mark paid'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(Bill bill, String currency) async {
    if (_paying.contains(bill.id)) return;
    final billsRepo = ref.read(billsRepoProvider);
    final txRepo = ref.read(transactionsRepoProvider);
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    if (billsRepo == null || txRepo == null) return;

    setState(() => _paying.add(bill.id));
    try {
      // Record the payment as a real expense, then roll the due date forward.
      final txId = const Uuid().v4();
      final tx = TransactionEntry(
        id: txId,
        clientId: txId,
        type: TxType.expense,
        amountMinor: bill.amountMinor,
        currency: currency,
        categoryId: bill.categoryId,
        accountId: accounts.isNotEmpty ? accounts.first.id : '',
        occurredAt: DateTime.now(),
        merchant: bill.name,
        source: TxSource.recurring,
      );
      await txRepo.upsert(tx, docId: tx.id);
      await billsRepo.upsert(bill.markPaid(DateTime.now()), docId: bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bill.name} marked paid — expense recorded.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark ${bill.name} paid. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying.remove(bill.id));
    }
  }

  void _showEditor(BuildContext context, String currency) {
    final name = TextEditingController();
    final amount = TextEditingController();
    var recurrence = BillRecurrence.monthly;
    var categoryId = 'utilities';
    var dueDate = DateTime.now().add(const Duration(days: 7));
    var saving = false;
    final formKey = GlobalKey<FormState>();
    final expenseCategories = (ref.read(categoriesStreamProvider).valueOrNull ?? Category.seeds)
        .where((c) => c.kind == TxType.expense)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
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
                  Text('Add recurring bill', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name (e.g. Rent, Electricity)'),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  DropdownButtonFormField<BillRecurrence>(
                    value: recurrence,
                    decoration: const InputDecoration(labelText: 'Repeats'),
                    items: [
                      for (final r in BillRecurrence.values)
                        DropdownMenuItem(value: r, child: Text(r.name)),
                    ],
                    onChanged: (v) => setSheetState(() => recurrence = v ?? recurrence),
                  ),
                  const SizedBox(height: FgTokens.s4),
                  DropdownButtonFormField<String>(
                    value: expenseCategories.any((c) => c.id == categoryId)
                        ? categoryId
                        : expenseCategories.firstOrNull?.id,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in expenseCategories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setSheetState(() => categoryId = v ?? categoryId),
                  ),
                  const SizedBox(height: FgTokens.s4),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FgTokens.rMd)),
                    tileColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Next due date'),
                    subtitle: Text(MaterialLocalizations.of(sheetContext).formatMediumDate(dueDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 366)),
                      );
                      if (picked != null) setSheetState(() => dueDate = picked);
                    },
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final repo = ref.read(billsRepoProvider);
                            if (repo == null) return;
                            setSheetState(() => saving = true);
                            try {
                              await repo.upsert(Bill(
                                id: '',
                                name: name.text.trim(),
                                amountMinor:
                                    Money.tryParseToMinor(amount.text, currency: currency)!,
                                currency: currency,
                                categoryId: categoryId,
                                recurrence: recurrence,
                                anchorDate: dueDate,
                                nextDueAt: dueDate,
                              ));
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not save the bill. Check your connection and try again.')),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save bill'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.markedDays,
    required this.selectedDay,
    required this.onSelect,
  });

  final DateTime month;
  final Set<int> markedDays;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon
    final today = DateTime.now();

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Center(
              child: Text(d,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        for (var i = 1; i < firstWeekday; i++) const SizedBox.shrink(),
        for (var day = 1; day <= daysInMonth; day++)
          _dayCell(theme, day,
              isToday: today.year == month.year &&
                  today.month == month.month &&
                  today.day == day),
      ],
    );
  }

  Widget _dayCell(ThemeData theme, int day, {required bool isToday}) {
    final isSelected = selectedDay == day;
    final hasBill = markedDays.contains(day);
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Day $day${hasBill ? ', bill due' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onSelect(day),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? theme.colorScheme.primary
                : isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : null,
            border: hasBill && !isSelected
                ? Border.all(color: FgTokens.gold, width: 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? theme.colorScheme.onPrimary : null,
                    fontWeight: isSelected || isToday ? FontWeight.w700 : null,
                  )),
              if (hasBill)
                Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.onPrimary : FgTokens.gold,
                        shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
