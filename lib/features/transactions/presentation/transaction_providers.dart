import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../core/utils/dates.dart';
import '../../accounts/domain/account.dart';
import '../../ai_assistant/domain/financial_aggregates.dart';
import '../../bills/presentation/bill_providers.dart';
import '../../budgets/domain/budget.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../insights/domain/financial_health.dart';
import '../domain/category.dart';
import '../domain/transaction_entry.dart';

/// Live streams + derived aggregates shared by dashboard, reports and AI.
final transactionsStreamProvider = StreamProvider<List<TransactionEntry>>((ref) {
  final repo = ref.watch(transactionsRepoProvider);
  if (repo == null) return Stream.value(const []);
  return repo
      .watchAll(build: (c) => c.orderBy('occurredAt', descending: true).limit(500))
      .map((txs) {
    // Resolved per emission (not once at provider build) so the pending badge
    // clears as soon as the queued write lands on the server.
    final pending = repo.pendingDocIds();
    return txs
        .map((t) => pending.contains(t.id) || pending.contains(t.clientId)
            ? t.copyWith(pendingSync: true)
            : t)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  });
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoriesRepoProvider);
  if (repo == null) return Stream.value(Category.seeds);
  return repo.watchAll().map((cats) => cats.isEmpty ? Category.seeds : (cats..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))));
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final repo = ref.watch(accountsRepoProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll().map((a) => a.where((x) => !x.archived).toList());
});

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final repo = ref.watch(budgetsRepoProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});

/// Current-month totals.
class MonthTotals {
  const MonthTotals({required this.incomeMinor, required this.expenseMinor, required this.byCategory});
  final int incomeMinor;
  final int expenseMinor;
  final Map<String, int> byCategory;
  int get netMinor => incomeMinor - expenseMinor;
}

final monthTotalsProvider = Provider<MonthTotals>((ref) {
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
  final key = Dates.periodKey(DateTime.now());
  final thisMonth = txs.where((t) => Dates.periodKey(t.occurredAt) == key);
  var income = 0, expense = 0;
  final byCategory = <String, int>{};
  for (final t in thisMonth) {
    if (t.categoryId == 'transfer') continue; // internal money movement

    if (t.type == TxType.income) {
      income += t.amountMinor;
    } else {
      expense += t.amountMinor;
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountMinor;
    }
  }
  return MonthTotals(incomeMinor: income, expenseMinor: expense, byCategory: byCategory);
});

/// Monthly net history (oldest first) for stability + forecasting.
final monthlyNetHistoryProvider = Provider<List<int>>((ref) {
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
  final byMonth = groupBy(txs, (TransactionEntry t) => Dates.periodKey(t.occurredAt));
  final keys = byMonth.keys.toList()..sort();
  return [
    for (final k in keys)
      byMonth[k]!.fold<int>(0, (sum, t) => sum + t.signedMinor),
  ];
});

/// Monthly expense history (oldest first) for expense forecasting.
final monthlyExpenseHistoryProvider = Provider<List<int>>((ref) {
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
  final expenses = txs.where((t) => t.type == TxType.expense);
  final byMonth = groupBy(expenses, (TransactionEntry t) => Dates.periodKey(t.occurredAt));
  final keys = byMonth.keys.toList()..sort();
  return [
    for (final k in keys)
      byMonth[k]!.fold<int>(0, (sum, t) => sum + t.amountMinor),
  ];
});

/// Budget progress for the current month, derived from live transactions.
final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? const <Budget>[];
  final totals = ref.watch(monthTotalsProvider);
  final key = Dates.periodKey(DateTime.now());
  return budgets
      .where((b) => b.periodKey == key)
      .map((b) => BudgetProgress(b, totals.byCategory[b.categoryId] ?? 0))
      .toList()
    ..sort((a, b) => b.ratio.compareTo(a.ratio));
});

/// Transparent financial-health score from live data.
final healthScoreProvider = Provider<HealthScore>((ref) {
  final totals = ref.watch(monthTotalsProvider);
  final history = ref.watch(monthlyNetHistoryProvider);
  final progress = ref.watch(budgetProgressProvider);
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const <Account>[];

  final liquid = accounts.where((a) => a.isLiquid).fold<int>(0, (s, a) => s + a.balanceMinor);
  final over = progress.where((p) => p.over).toList();
  final (paidOnTime, due) = ref.watch(billPunctualityProvider);

  return const FinancialHealth().compute(FinancialHealthInput(
    monthlyIncomeMinor: totals.incomeMinor,
    monthlyExpenseMinor: totals.expenseMinor,
    monthlyNetHistory: history,
    budgetsKept: progress.length - over.length,
    budgetsTotal: progress.length,
    budgetOverspendRatios: over.map((p) => p.ratio).toList(),
    liquidBalanceMinor: liquid,
    billsDue: due,
    billsPaidOnTime: paidOnTime,
  ));
});

/// Minimised aggregates for AI prompts — never raw transactions.
final financialAggregatesProvider = Provider<FinancialAggregates>((ref) {
  final totals = ref.watch(monthTotalsProvider);
  final health = ref.watch(healthScoreProvider);
  final progress = ref.watch(budgetProgressProvider);
  final expenseHistory = ref.watch(monthlyExpenseHistoryProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;

  return FinancialAggregates(
    currency: profile?.prefs.currency ?? 'LKR',
    monthKey: Dates.periodKey(DateTime.now()),
    incomeMinor: totals.incomeMinor,
    expenseMinor: totals.expenseMinor,
    byCategory: totals.byCategory,
    healthScore: health.score,
    budgetCount: progress.length,
    budgetsOver: progress.where((p) => p.over).length,
    goalCount: ref.watch(goalsStreamProvider).valueOrNull?.length ?? 0,
    upcomingBillCount: ref.watch(upcomingBillsProvider).length,
    previousMonthExpenseMinor:
        expenseHistory.length >= 2 ? expenseHistory[expenseHistory.length - 2] : null,
  );
});
