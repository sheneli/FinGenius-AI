import 'dart:math' as math;

/// Financial-health score: a transparent 0–100 composite. **Not a credit score.**
///
/// Documented formula (weights sum to 1.0):
///   score = 100 * ( 0.30*savingsRate' + 0.25*budgetAdherence
///                 + 0.20*cashflowStability + 0.15*emergencyFund'
///                 + 0.10*billPunctuality )
///
/// - savingsRate'      = clamp(savingsRate / 0.20, 0, 1)   — saving ≥20% of income scores full marks
/// - budgetAdherence   = share of budgets kept within limit (partial credit down to 2× overspend)
/// - cashflowStability = 1 − clamp(cv, 0, 1) where cv = stdev/mean of monthly net cash flow
/// - emergencyFund'    = clamp(liquidBalance / (3 × avgMonthlyExpenses), 0, 1) — 3 months = full marks
/// - billPunctuality   = onTimeBills / dueBills (1.0 when no bills — no penalty for absence)
///
/// Each factor is reported individually so the UI can show *why* and how to improve.
class HealthFactor {
  const HealthFactor(this.key, this.label, this.value, this.weight, this.hint);
  final String key;
  final String label;
  final double value; // 0..1
  final double weight; // 0..1
  final String hint;
  double get contribution => value * weight * 100;
}

class HealthScore {
  const HealthScore(this.score, this.factors, {this.insufficientData = false});
  final int score;
  final List<HealthFactor> factors;
  final bool insufficientData;
}

class FinancialHealthInput {
  const FinancialHealthInput({
    required this.monthlyIncomeMinor,
    required this.monthlyExpenseMinor,
    required this.monthlyNetHistory,
    required this.budgetsKept,
    required this.budgetsTotal,
    required this.budgetOverspendRatios,
    required this.liquidBalanceMinor,
    required this.billsDue,
    required this.billsPaidOnTime,
  });

  final int monthlyIncomeMinor;
  final int monthlyExpenseMinor;
  final List<int> monthlyNetHistory; // recent months, oldest first
  final int budgetsKept;
  final int budgetsTotal;
  final List<double> budgetOverspendRatios; // spent/limit for overspent budgets
  final int liquidBalanceMinor;
  final int billsDue;
  final int billsPaidOnTime;
}

class FinancialHealth {
  const FinancialHealth();

  HealthScore compute(FinancialHealthInput i) {
    final insufficient = i.monthlyIncomeMinor <= 0 && i.monthlyExpenseMinor <= 0;

    final savingsRate = i.monthlyIncomeMinor <= 0
        ? 0.0
        : (i.monthlyIncomeMinor - i.monthlyExpenseMinor) / i.monthlyIncomeMinor;
    final savings = _clamp01(savingsRate / 0.20);

    double adherence;
    if (i.budgetsTotal == 0) {
      adherence = 0.5; // neutral: no budgets set yet — encourage creating them
    } else {
      var credit = i.budgetsKept.toDouble();
      for (final ratio in i.budgetOverspendRatios) {
        // Partial credit: 1.0 at ratio<=1 tapering to 0 at ratio>=2.
        credit += _clamp01(2.0 - ratio);
      }
      adherence = _clamp01(credit / i.budgetsTotal);
    }

    double stability;
    if (i.monthlyNetHistory.length < 3) {
      stability = 0.5; // honest neutral when history is too short
    } else {
      final mean = i.monthlyNetHistory.reduce((a, b) => a + b) / i.monthlyNetHistory.length;
      if (mean.abs() < 1) {
        stability = 0.0;
      } else {
        final variance = i.monthlyNetHistory
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            i.monthlyNetHistory.length;
        final cv = math.sqrt(variance) / mean.abs();
        stability = _clamp01(1 - cv);
      }
    }

    final avgExpense = i.monthlyExpenseMinor;
    final emergency = avgExpense <= 0 ? 0.5 : _clamp01(i.liquidBalanceMinor / (3.0 * avgExpense));

    final punctuality = i.billsDue == 0 ? 1.0 : _clamp01(i.billsPaidOnTime / i.billsDue);

    final factors = [
      HealthFactor('savingsRate', 'Savings rate', savings, 0.30,
          'Aim to save at least 20% of your income each month.'),
      HealthFactor('budgetAdherence', 'Budget adherence', adherence, 0.25,
          'Keep spending within the budgets you set — small, realistic limits work best.'),
      HealthFactor('cashflowStability', 'Cash-flow stability', stability, 0.20,
          'Smoother month-to-month cash flow raises this factor.'),
      HealthFactor('emergencyFund', 'Emergency fund', emergency, 0.15,
          'Build towards 3 months of expenses in accessible savings.'),
      HealthFactor('billPunctuality', 'Bill punctuality', punctuality, 0.10,
          'Paying bills on or before their due date keeps this at 100%.'),
    ];

    final score = factors.fold<double>(0, (sum, f) => sum + f.contribution).round().clamp(0, 100);
    return HealthScore(score, factors, insufficientData: insufficient);
  }

  static double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
}
