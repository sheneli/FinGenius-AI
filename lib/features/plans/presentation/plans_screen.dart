import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/fintech.dart';
import '../../bills/presentation/bill_providers.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Hub for budgets, goals, bills, subscriptions and reports.
///
/// v3 presentation: a live "planning at a glance" strip over the same grouped
/// navigation rows. Every destination and every derived count is unchanged.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgets = ref.watch(budgetProgressProvider);
    final goals = ref.watch(goalsStreamProvider).valueOrNull ?? [];
    final upcoming = ref.watch(upcomingBillsProvider);
    final currency =
        ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    final overCount = budgets.where((b) => b.over).length;
    final dueMinor = upcoming.fold<int>(0, (s, b) => s + b.amountMinor);
    final savedMinor = goals.fold<int>(0, (s, g) => s + g.savedMinor);

    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            FgTokens.s4, FgTokens.s2, FgTokens.s4, FgTokens.s10),
        children: [
          // At-a-glance strip — all values derived from live providers.
          Row(children: [
            Expanded(
              child: MiniStatCard(
                label: 'Budgets over',
                value: '$overCount of ${budgets.length}',
                tint: overCount > 0 ? FgTokens.error : FgTokens.success,
                onTap: () => context.go('/plans/budgets'),
              ),
            ),
            const SizedBox(width: FgTokens.s3),
            Expanded(
              child: MiniStatCard(
                label: 'Saved in goals',
                value: Money(savedMinor, currency).format(compact: true),
                tint: FgTokens.cyan,
                onTap: () => context.go('/plans/goals'),
              ),
            ),
            const SizedBox(width: FgTokens.s3),
            Expanded(
              child: MiniStatCard(
                label: 'Due (14 days)',
                value: Money(dueMinor, currency).format(compact: true),
                tint: FgTokens.gold,
                onTap: () => context.go('/plans/bills'),
              ),
            ),
          ]),

          const FinSectionHeader('Manage'),
          RowGroup(children: [
            FinListRow(
              icon: Icons.pie_chart_outline,
              iconTint: FgTokens.green,
              title: 'Budgets',
              subtitle: budgets.isEmpty
                  ? 'Set monthly spending limits'
                  : '${budgets.length} active · $overCount over',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plans/budgets'),
            ),
            FinListRow(
              icon: Icons.flag_outlined,
              iconTint: FgTokens.cyan,
              title: 'Savings goals',
              subtitle: goals.isEmpty
                  ? 'Save towards something that matters'
                  : '${goals.length} in progress',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plans/goals'),
            ),
            FinListRow(
              icon: Icons.event_outlined,
              iconTint: FgTokens.gold,
              title: 'Bills & calendar',
              subtitle: upcoming.isEmpty
                  ? 'Track recurring bills'
                  : '${upcoming.length} due in the next 14 days',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plans/bills'),
            ),
            FinListRow(
              icon: Icons.subscriptions_outlined,
              iconTint: const Color(0xFF9F7AEA),
              title: 'Subscriptions',
              subtitle: 'Detected recurring payments',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plans/subscriptions'),
            ),
          ]),

          const FinSectionHeader('Understand'),
          RowGroup(children: [
            FinListRow(
              icon: Icons.query_stats,
              iconTint: FgTokens.info,
              title: 'Reports & analytics',
              subtitle: 'Trends, forecasts and the health-score breakdown',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/plans/reports'),
            ),
          ]),

          const SizedBox(height: FgTokens.s4),
          Text(
            'Plans are educational tools — not financial advice.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
