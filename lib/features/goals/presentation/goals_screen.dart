import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/states.dart';
import '../domain/goal.dart';
import 'goal_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(goalsStreamProvider);
    final currency = ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalEditor(context, ref, currency),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: AsyncValueView(
        value: goalsAsync,
        onRetry: () => ref.invalidate(goalsStreamProvider),
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              title: 'No goals yet',
              message: 'A deposit, a trip, an emergency fund — pick a target and watch progress build.',
              actionLabel: 'Create a goal',
              onAction: () => _showGoalEditor(context, ref, currency),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(FgTokens.s4, FgTokens.s4, FgTokens.s4, 96),
            children: [
              for (final g in goals)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FgTokens.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(g.name,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Text('${(g.progress * 100).round()}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                        ]),
                        const SizedBox(height: FgTokens.s3),
                        Semantics(
                          label: '${g.name}: ${Money(g.savedMinor, currency).format()} of ${Money(g.targetMinor, currency).format()} saved',
                          child: LinearProgressIndicator(
                            value: g.progress, minHeight: 8,
                            borderRadius: BorderRadius.circular(FgTokens.rPill),
                          ),
                        ),
                        const SizedBox(height: FgTokens.s2),
                        Text(
                          '${Money(g.savedMinor, currency).format()} of ${Money(g.targetMinor, currency).format()}'
                          '${_projection(g)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: FgTokens.s3),
                        Row(children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.add, size: FgTokens.iconSm),
                            label: const Text('Contribute'),
                            onPressed: () => _showContributeSheet(context, ref, g, currency),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Delete goal',
                            icon: Icon(Icons.delete_outline, size: FgTokens.iconSm, color: theme.colorScheme.error),
                            onPressed: () async {
                              final confirmed = await showConfirmSheet(
                                context,
                                title: 'Delete goal "${g.name}"?',
                                message: 'This goal and its savings history will be removed.',
                                confirmLabel: 'Delete',
                                destructive: true,
                              );
                              if (confirmed) {
                                await ref.read(goalsRepoProvider)?.delete(g.id);
                              }
                            },
                          ),
                        ]),
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

  String _projection(Goal g) {
    final projected = g.projectedCompletion();
    if (g.savedMinor >= g.targetMinor) return ' · achieved 🎉';
    if (projected == null) return '';
    return ' · on pace for ${DateFormat.yMMM().format(projected)} (estimate from your actual contributions)';
  }

  void _showGoalEditor(BuildContext context, WidgetRef ref, String currency) {
    final name = TextEditingController();
    final target = TextEditingController();
    DateTime? deadline;
    var saving = false;
    final formKey = GlobalKey<FormState>();

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
                  Text('New goal', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'What are you saving for?'),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Target amount'),
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: FgTokens.s4),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FgTokens.rMd)),
                    tileColor:
                        Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Target date (optional)'),
                    subtitle: Text(deadline == null
                        ? 'No deadline'
                        : MaterialLocalizations.of(sheetContext)
                            .formatMediumDate(deadline!)),
                    trailing: deadline == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear date',
                            icon: const Icon(Icons.close),
                            onPressed: () => setSheetState(() => deadline = null),
                          ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate:
                            deadline ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
                      );
                      if (picked != null) setSheetState(() => deadline = picked);
                    },
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final repo = ref.read(goalsRepoProvider);
                            if (repo == null) return;
                            setSheetState(() => saving = true);
                            try {
                              await repo.upsert(Goal(
                                id: '',
                                name: name.text.trim(),
                                targetMinor: Money.tryParseToMinor(target.text,
                                    currency: currency)!,
                                savedMinor: 0,
                                currency: currency,
                                deadline: deadline,
                              ));
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not create the goal. Check your connection and try again.')),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create goal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContributeSheet(BuildContext context, WidgetRef ref, Goal goal, String currency) {
    final amount = TextEditingController();
    var saving = false;
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
                  Text('Contribute to "${goal.name}"', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: FgTokens.s4),
                  TextFormField(
                    controller: amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: FgTokens.s6),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final repo = ref.read(goalsRepoProvider);
                            if (repo == null) return;
                            setSheetState(() => saving = true);
                            try {
                              final minor =
                                  Money.tryParseToMinor(amount.text, currency: currency)!;
                              final updated = goal.copyWith(
                                savedMinor: goal.savedMinor + minor,
                                contributions: [
                                  ...goal.contributions,
                                  GoalContribution(minor, DateTime.now())
                                ],
                              );
                              await repo.upsert(updated, docId: goal.id);
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not save the contribution. Check your connection and try again.')),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add contribution'),
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
