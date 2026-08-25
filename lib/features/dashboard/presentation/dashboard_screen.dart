import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/security/secure_screen.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/fintech.dart';
import '../../../core/widgets/health_gauge.dart';
import '../../../core/widgets/states.dart';
import '../../bills/presentation/bill_providers.dart';
import '../../budgets/domain/budget.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../insights/domain/forecasting.dart';
import '../../transactions/domain/category.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/transaction_tile.dart';
import 'spending_breakdown_section.dart';

/// Which photo the header avatar shows.
///
/// The in-app upload wins over the identity provider's picture. Uploads are
/// written to `users/{uid}.photoUrl` and never to the Firebase Auth record, so
/// preferring `authPhotoUrl` pinned the header to a stale Google avatar on
/// federated accounts: the profile screen showed the freshly uploaded photo
/// while this header kept the old one indefinitely.
///
/// A blank (not just null) stored value falls through too — clearing a photo
/// writes a delete, but a half-written empty string must not blank the header.
String? resolveHeaderPhoto({String? profilePhotoUrl, String? authPhotoUrl}) {
  final owned = profilePhotoUrl?.trim();
  if (owned != null && owned.isNotEmpty) return owned;
  final provider = authPhotoUrl?.trim();
  return (provider != null && provider.isNotEmpty) ? provider : null;
}

/// Home. Modular sections, each independently derived — reorderable by
/// construction and cheap to rebuild (each watches only what it needs).
///
/// v3: fintech presentation (greeting header, gradient hero, quick-action
/// tiles, grouped rows) over exactly the same providers, callbacks and routes
/// as before — this screen still owns all data; the widgets only render it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final currency = profile?.prefs.currency ?? 'LKR';
    final txsAsync = ref.watch(transactionsStreamProvider);
    final totals = ref.watch(monthTotalsProvider);
    final health = ref.watch(healthScoreProvider);
    final budgets = ref.watch(budgetProgressProvider);
    final goals = ref.watch(goalsStreamProvider).valueOrNull ?? [];
    final upcomingBills = ref.watch(upcomingBillsProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? Category.seeds;
    final catById = {for (final c in categories) c.id: c};
    final expenseHistory = ref.watch(monthlyExpenseHistoryProvider);
    final netHistory = ref.watch(monthlyNetHistoryProvider);

    final netWorth = accounts.fold<int>(0, (s, a) => s + a.balanceMinor);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = profile?.displayName.split(' ').firstOrNull ?? '';
    final forecast = const Forecaster().forecast(expenseHistory);

    final authUser = ref.watch(authStateProvider).valueOrNull;
    final headerPhoto = resolveHeaderPhoto(
      profilePhotoUrl: profile?.photoUrl,
      authPhotoUrl: authUser?.photoURL,
    );
    final headerInitial = (name.isNotEmpty ? name : (authUser?.email ?? '?'))
        .substring(0, 1)
        .toUpperCase();
    final hideBalances = profile?.prefs.hideBalances ?? false;

    // Savings rate for the hero delta chip — derived from this month's real
    // totals; hidden entirely when there is no income to divide by.
    final savingsRate = totals.incomeMinor > 0
        ? (totals.netMinor / totals.incomeMinor * 100).round()
        : null;

    return SecureScreen(
      child: Scaffold(
        body: AsyncValueView(
          value: txsAsync,
          onRetry: () => ref.invalidate(transactionsStreamProvider),
          data: (txs) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(transactionsStreamProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  FgTokens.s4, FgTokens.s2, FgTokens.s4, FgTokens.s10),
              children: [
                // ── Greeting header ────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: FgTokens.s4),
                    child: GreetingHeader(
                      greeting: greeting,
                      title: name.isEmpty ? 'Welcome back' : name,
                      subtitle:
                          Dates.monthLabel(Dates.periodKey(DateTime.now())),
                      leading: Semantics(
                        button: true,
                        label: 'Open profile',
                        child: GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: ProfileAvatar(
                            photoUrl: headerPhoto,
                            initial: headerInitial,
                            size: 46,
                            editable: false,
                          ),
                        ),
                      ),
                      actions: [
                        SquareIconButton(
                          icon: hideBalances
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          tooltip:
                              hideBalances ? 'Show balances' : 'Hide balances',
                          onPressed: () async {
                            final uid = ref.read(currentUidProvider);
                            if (uid == null || profile == null) return;
                            await ref
                                .read(firestoreProvider)
                                .doc('users/$uid')
                                .set({
                              'prefs': {
                                'hideBalances': !profile.prefs.hideBalances
                              },
                            }, SetOptions(merge: true));
                          },
                        ),
                        SquareIconButton(
                          icon: Icons.notifications_none,
                          tooltip: 'Notifications',
                          onPressed: () => context.go('/home/notifications'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hero: net worth + this month's flows ───────────────────
                FadeSlideIn(
                  child: BalanceHeroCard(
                    label: 'Net worth',
                    deltaLabel:
                        savingsRate == null ? null : '$savingsRate% saved',
                    deltaPositive: totals.netMinor >= 0,
                    onTap: () => context.go('/home/accounts'),
                    amount: AmountText(Money(netWorth, currency)),
                    footer: Row(children: [
                      HeroStat(
                        label: 'Income',
                        icon: Icons.south_west,
                        value: AmountText(Money(totals.incomeMinor, currency),
                            compact: true),
                      ),
                      HeroStat(
                        label: 'Expenses',
                        icon: Icons.north_east,
                        value: AmountText(Money(totals.expenseMinor, currency),
                            compact: true),
                      ),
                      HeroStat(
                        label: 'Savings',
                        icon: Icons.savings_outlined,
                        value: AmountText(Money(totals.netMinor, currency),
                            compact: true),
                      ),
                    ]),
                  ),
                ),

                // ── Quick actions (same destinations as before) ────────────
                const SizedBox(height: FgTokens.s5),
                QuickActionsRow(actions: [
                  QuickAction(
                    label: 'Add',
                    icon: Icons.add_circle_outline,
                    onTap: () => context.go('/transactions/add'),
                  ),
                  QuickAction(
                    label: 'Scan',
                    icon: Icons.document_scanner_outlined,
                    onTap: () => context.go('/transactions/scan'),
                  ),
                  QuickAction(
                    label: 'Accounts',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => context.go('/home/accounts'),
                  ),
                  QuickAction(
                    label: 'Reports',
                    icon: Icons.query_stats,
                    onTap: () => context.go('/plans/reports'),
                  ),
                  // Assistant is intentionally not here — it already has its
                  // own bottom-nav tab, and four tiles fit the row exactly.
                ]),

                // ── Trend mini-cards (real history, only when meaningful) ──
                if (expenseHistory.length > 1 || netHistory.length > 1) ...[
                  const SizedBox(height: FgTokens.s4),
                  Row(children: [
                    if (expenseHistory.length > 1)
                      Expanded(
                        child: MiniStatCard(
                          label: 'Monthly spend',
                          value: Money(expenseHistory.last, currency)
                              .format(compact: true),
                          spark: [for (final v in expenseHistory) v.toDouble()],
                          tint: FgTokens.error,
                          onTap: () => context.go('/plans/reports'),
                        ),
                      ),
                    if (expenseHistory.length > 1 && netHistory.length > 1)
                      const SizedBox(width: FgTokens.s3),
                    if (netHistory.length > 1)
                      Expanded(
                        child: MiniStatCard(
                          label: 'Net cash flow',
                          value: Money(netHistory.last, currency)
                              .format(compact: true),
                          spark: [for (final v in netHistory) v.toDouble()],
                          tint: netHistory.last >= 0
                              ? FgTokens.success
                              : FgTokens.warning,
                          onTap: () => context.go('/plans/reports'),
                        ),
                      ),
                  ]),
                ],

                // ── Financial health ───────────────────────────────────────
                const FinSectionHeader('Financial health'),
                FadeSlideIn(
                  delayMs: 60,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FgTokens.s4),
                      child: Row(children: [
                        HealthGauge(score: health.score, size: 110),
                        const SizedBox(width: FgTokens.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final f in health.factors.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: FgTokens.s2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(f.label,
                                                style:
                                                    theme.textTheme.bodySmall)),
                                        Text('${(f.value * 100).round()}%',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                      ]),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            FgTokens.rPill),
                                        child: LinearProgressIndicator(
                                          value: f.value.clamp(0.0, 1.0),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                'Not a credit score — tap Plans → Reports for the full breakdown.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                // ── Spending breakdown with Day/Week/Month/Year filters ────
                FinSectionHeader('Spending breakdown',
                    actionLabel: 'Reports',
                    onAction: () => context.go('/plans/reports')),
                FadeSlideIn(
                  delayMs: 120,
                  child: SpendingBreakdownSection(
                      categories: catById, currency: currency),
                ),

                // ── Forecast strip (honest) ────────────────────────────────
                if (!forecast.insufficientData) ...[
                  const FinSectionHeader('Next month, roughly'),
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: FgTokens.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(FgTokens.rMd),
                        ),
                        child: const Icon(Icons.query_stats,
                            color: FgTokens.gold, size: FgTokens.iconMd),
                      ),
                      title: Text(
                        '${Money(forecast.points.first.lowMinor, currency).format(compact: true)} – '
                        '${Money(forecast.points.first.highMinor, currency).format(compact: true)} expected spend',
                      ),
                      subtitle: Text(
                          'Confidence: ${forecast.confidence} · based on ${expenseHistory.length} months'),
                    ),
                  ),
                ],

                // ── Budgets ────────────────────────────────────────────────
                if (budgets.isNotEmpty) ...[
                  FinSectionHeader('Budgets',
                      actionLabel: 'Manage',
                      onAction: () => context.go('/plans/budgets')),
                  for (final p in budgets.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: FgTokens.s3),
                      child: _budgetRow(context, p, catById, currency),
                    ),
                ],

                // ── Goals ──────────────────────────────────────────────────
                if (goals.isNotEmpty) ...[
                  FinSectionHeader('Goals',
                      actionLabel: 'All goals',
                      onAction: () => context.go('/plans/goals')),
                  RowGroup(children: [
                    for (final g in goals.take(2))
                      FinListRow(
                        icon: Icons.flag_outlined,
                        iconTint: FgTokens.cyan,
                        title: g.name,
                        subtitle:
                            '${Money(g.savedMinor, currency).format(compact: true)} of ${Money(g.targetMinor, currency).format(compact: true)}',
                        semanticLabel:
                            '${g.name}: ${(g.progress * 100).round()} percent saved',
                        onTap: () => context.go('/plans/goals'),
                        trailing: Text(
                          '${(g.progress * 100).round()}%',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ]),
                ],

                // ── Upcoming bills ─────────────────────────────────────────
                if (upcomingBills.isNotEmpty) ...[
                  FinSectionHeader('Upcoming bills',
                      actionLabel: 'Calendar',
                      onAction: () => context.go('/plans/bills')),
                  RowGroup(children: [
                    for (final b in upcomingBills.take(3))
                      FinListRow(
                        icon: b.isOverdue
                            ? Icons.warning_amber
                            : Icons.event_outlined,
                        iconTint: b.isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        title: b.name,
                        subtitle: b.isOverdue
                            ? 'Overdue — ${Dates.friendly(b.nextDueAt)}'
                            : Dates.friendly(b.nextDueAt),
                        onTap: () => context.go('/plans/bills'),
                        trailing: AmountText(Money(b.amountMinor, currency)),
                      ),
                  ]),
                ],

                // ── Recent transactions ────────────────────────────────────
                FinSectionHeader('Recent activity',
                    actionLabel: 'See all',
                    onAction: () => context.go('/transactions')),
                if (txs.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity yet',
                    message:
                        'Add your first transaction to bring this dashboard to life.',
                    actionLabel: 'Add transaction',
                    onAction: () => context.go('/transactions/add'),
                  )
                else
                  RowGroup(children: [
                    for (final tx in txs.take(5))
                      TransactionTile(
                        tx: tx,
                        category: catById[tx.categoryId],
                        onTap: () => context.go('/transactions/${tx.id}'),
                      ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _budgetRow(BuildContext context, BudgetProgress p,
      Map<String, Category> catById, String currency) {
    final theme = Theme.of(context);
    final name = catById[p.budget.categoryId]?.name ?? p.budget.categoryId;
    final ratio = p.ratio.clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FgTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                '${Money(p.spentMinor, currency).format(compact: true)} / ${Money(p.budget.limitMinor, currency).format(compact: true)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: p.over
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: p.over ? FontWeight.w700 : null,
                ),
              ),
            ]),
            const SizedBox(height: FgTokens.s3),
            Semantics(
              label:
                  '$name budget ${(ratio * 100).round()} percent used${p.over ? ', over limit' : ''}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FgTokens.rPill),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: p.over
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
