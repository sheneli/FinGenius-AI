import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/states.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/budget.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(budgetProgressProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final categories = (ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds)
        .where((c) => c.kind == TxType.expense)
        .toList();
    final catById = {for (final c in categories) c.id: c};
    final currency = ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(title: Text('Budgets · ${Dates.monthLabel(Dates.periodKey(DateTime.now()))}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref, categories, currency),
        icon: const Icon(Icons.add),
        label: const Text('New budget'),
      ),
      body: AsyncValueView(
        value: budgetsAsync,
        onRetry: () => ref.invalidate(budgetsStreamProvider),
        data: (_) {
          if (progress.isEmpty) {
            return EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No budgets this month',
              message: 'Set a limit for a category and FinGenius will track it against your real spending.',
              actionLabel: 'Create a budget',
              onAction: () => _showEditor(context, ref, categories, currency),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(FgTokens.s4, FgTokens.s4, FgTokens.s4, 96),
            children: [
              for (final p in progress)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FgTokens.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(catById[p.budget.categoryId]?.name ?? p.budget.categoryId,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          if (p.over)
                            Chip(
                              label: const Text('Over'),
                              labelStyle: theme.textTheme.labelSmall,
                              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.16),
                              visualDensity: VisualDensity.compact,
                            )
                          else if (p.ratio >= 0.8)
                            Chip(
                              label: const Text('Close'),
                              labelStyle: theme.textTheme.labelSmall,
                              backgroundColor: FgTokens.warning.withValues(alpha: 0.16),
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            tooltip: 'Edit budget',
                            icon: const Icon(Icons.edit_outlined, size: FgTokens.iconMd),
                            onPressed: () => _showEditor(context, ref, categories, currency, existing: p.budget),
                          ),
                        ]),
                        const SizedBox(height: FgTokens.s2),
                        Semantics(
                          label: 'Budget ${catById[p.budget.categoryId]?.name}: '
                              '${Money(p.spentMinor, currency).format()} of ${Money(p.budget.limitMinor, currency).format()} used',
                          child: LinearProgressIndicator(
                            value: p.ratio.clamp(0.0, 1.0),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(FgTokens.rPill),
                            color: p.over
                                ? theme.colorScheme.error
                                : p.ratio >= 0.8
                                    ? FgTokens.warning
                                    : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: FgTokens.s2),
                        Text(
                          '${Money(p.spentMinor, currency).format()} of ${Money(p.budget.limitMinor, currency).format()}'
                          '${p.over ? ' · ${Money(p.spentMinor - p.budget.limitMinor, currency).format()} over' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, List<Category> categories, String currency, {Budget? existing}) {
    final limit = TextEditingController(
        text: existing == null ? '' : (existing.limitMinor / 100).toStringAsFixed(2));
    String? categoryId = existing?.categoryId ?? categories.firstOrNull?.id;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
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
                  Text(existing == null ? 'New budget' : 'Edit budget',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: FgTokens.s4),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: existing == null ? (v) => setSheetState(() => categoryId = v) : null,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: limit,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monthly limit'),
                    validator: (v) {
                      final minor = Money.tryParseToMinor(v ?? '', currency: currency);
                      return (minor == null || minor <= 0) ? 'Enter a limit greater than zero' : null;
                    },
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate() || categoryId == null) return;
                      final repo = ref.read(budgetsRepoProvider);
                      if (repo == null) return;
                      final periodKey = Dates.periodKey(DateTime.now());
                      final budget = Budget(
                        id: existing?.id ?? '${categoryId}_$periodKey',
                        categoryId: categoryId!,
                        periodKey: periodKey,
                        limitMinor: Money.tryParseToMinor(limit.text, currency: currency)!,
                        currency: currency,
                      );
                      await repo.upsert(budget, docId: budget.id);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Save budget'),
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
