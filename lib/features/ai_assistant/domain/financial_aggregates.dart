/// Minimised, aggregated view of the user's finances — the ONLY financial data
/// ever included in AI prompts. No merchants, notes, account names, or
/// individual transactions (data minimisation; see docs/privacy_data_flow.md).
class FinancialAggregates {
  const FinancialAggregates({
    required this.currency,
    required this.monthKey,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.byCategory,
    required this.healthScore,
    required this.budgetCount,
    required this.budgetsOver,
    required this.goalCount,
    required this.upcomingBillCount,
    this.previousMonthExpenseMinor,
  });

  final String currency;
  final String monthKey;
  final int incomeMinor;
  final int expenseMinor;
  final Map<String, int> byCategory; // categoryId -> spent minor
  final int healthScore;
  final int budgetCount;
  final int budgetsOver;
  final int goalCount;
  final int upcomingBillCount;
  final int? previousMonthExpenseMinor;

  String toPromptBlock() {
    final lines = <String>[
      'Month: $monthKey',
      'Income: ${_fmt(incomeMinor)}',
      'Expenses: ${_fmt(expenseMinor)}',
      if (previousMonthExpenseMinor != null) 'Previous month expenses: ${_fmt(previousMonthExpenseMinor!)}',
      'Financial-health score (0-100, app-defined, not a credit score): $healthScore',
      'Budgets: $budgetCount set, $budgetsOver over limit',
      'Savings goals: $goalCount',
      'Bills due in next 14 days: $upcomingBillCount',
      'Spending by category:',
      ...byCategory.entries.map((e) => '  - ${e.key}: ${_fmt(e.value)}'),
    ];
    return lines.join('\n');
  }

  String _fmt(int minor) => (minor / 100).toStringAsFixed(2);
}
