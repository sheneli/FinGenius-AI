import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../core/widgets/health_gauge.dart';
import '../../../core/widgets/range_selector.dart';
import '../../budgets/domain/budget.dart';
import '../../insights/domain/forecasting.dart';
import '../../transactions/domain/period.dart';
import '../../transactions/presentation/granularity_bar.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'range_providers.dart';

/// Per-chart granularity selections — session-scoped.
final cashFlowGranularityProvider =
    StateProvider<PeriodGranularity>((_) => PeriodGranularity.month);
final expenseTrendGranularityProvider =
    StateProvider<PeriodGranularity>((_) => PeriodGranularity.month);

/// Month shown by the budget-vs-actual card (budgets are defined per month).
final budgetReportMonthProvider = StateProvider<DateTime>(
    (_) => DateTime(DateTime.now().year, DateTime.now().month));

int _bucketCountFor(PeriodGranularity g) => switch (g) {
      PeriodGranularity.day => 14,
      PeriodGranularity.week => 12,
      PeriodGranularity.month => 12,
      PeriodGranularity.year => 5,
    };

/// Reports: cash-flow trend, expense trend + forecast band, budget-vs-actual,
/// health-score factor breakdown — every chart with Day/Week/Month/Year
/// filters computed from persisted transactions only.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';
    final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const <TransactionEntry>[];
    final health = ref.watch(healthScoreProvider);

    final cashGranularity = ref.watch(cashFlowGranularityProvider);
    final trendGranularity = ref.watch(expenseTrendGranularityProvider);
    final budgetMonth = ref.watch(budgetReportMonthProvider);

    // ── Bucketed series from persisted data ───────────────────────────────
    final netSeries = PeriodTotals.series(txs,
        granularity: cashGranularity, count: _bucketCountFor(cashGranularity));
    final expenseSeries = PeriodTotals.series(txs,
        granularity: trendGranularity,
        count: _bucketCountFor(trendGranularity),
        expensesOnly: true);
    // Only forecast from buckets with any history at all.
    final expenseHistory = [for (final (_, v) in expenseSeries) v];
    final forecast = const Forecaster().forecast(expenseHistory);
    final backtest = const Forecaster().backtest(expenseHistory);

    // ── Budget vs actual for the chosen month ─────────────────────────────
    final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? const <Budget>[];
    final budgetKey = Dates.periodKey(budgetMonth);
    final monthTotals = PeriodTotals.compute(
        txs, Period.containing(budgetMonth, PeriodGranularity.month));
    final budgetRows = budgets
        .where((b) => b.periodKey == budgetKey)
        .map((b) => (b, monthTotals.byCategory[b.categoryId] ?? 0))
        .toList()
      ..sort((a, b) {
        final ra = a.$1.limitMinor == 0 ? 0.0 : a.$2 / a.$1.limitMinor;
        final rb = b.$1.limitMinor == 0 ? 0.0 : b.$2 / b.$1.limitMinor;
        return rb.compareTo(ra);
      });

    String money(int minor) => Money(minor, currency).format(compact: true);
    String rangeLabel(List<(Period, int)> series) => series.isEmpty
        ? ''
        : '${series.first.$1.label()} – ${series.last.$1.label()}';

    final range = ref.watch(chartRangeProvider);
    final series = ref.watch(rangeSeriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & analytics')),
      body: ListView(
        padding: const EdgeInsets.all(FgTokens.s4),
        children: [
          // ---- Range-aware income vs expense ----
          RangeSelector(
            value: range,
            onChanged: (r) => ref.read(chartRangeProvider.notifier).state = r,
          ),
          const SizedBox(height: FgTokens.s3),
          ChartContainer(
            title: 'Income vs expenses · ${range.label.toLowerCase()} view',
            isEmpty: series.isEmpty,
            emptyMessage: 'No transactions in this period yet.',
            textSummary: series.isEmpty
                ? 'No data.'
                : 'Across ${series.length} ${range.label.toLowerCase()} buckets: income '
                    '${money(series.fold<int>(0, (s, p) => s + p.incomeMinor))}, expenses '
                    '${money(series.fold<int>(0, (s, p) => s + p.expenseMinor))}.',
            tableAlternative: Column(children: [
              for (final p in series.reversed.take(12))
                ListTile(
                  dense: true,
                  title: Text(p.bucket),
                  subtitle: Text('In ${money(p.incomeMinor)} · Out ${money(p.expenseMinor)}'),
                  trailing: Text(money(p.netMinor)),
                ),
            ]),
            chart: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        money(rod.toY.round()),
                        theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < series.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: series[i].incomeMinor.toDouble(),
                          color: FgTokens.success,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: series[i].expenseMinor.toDouble(),
                          color: FgTokens.error,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: FgTokens.s4),
          // ── Health-score breakdown ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FgTokens.s4),
              child: Column(children: [
                HealthGauge(score: health.score, size: 130),
                const SizedBox(height: FgTokens.s4),
                for (final f in health.factors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FgTokens.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(f.label, style: theme.textTheme.bodyMedium)),
                          Text('${(f.value * 100).round()}% · weight ${(f.weight * 100).round()}%',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ]),
                        const SizedBox(height: FgTokens.s1),
                        Semantics(
                          label: '${f.label}: ${(f.value * 100).round()} percent. ${f.hint}',
                          child: LinearProgressIndicator(value: f.value, minHeight: 5),
                        ),
                        const SizedBox(height: FgTokens.s1),
                        Text(f.hint,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                Text(
                  'A transparent wellness indicator computed on your device — not a credit score.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          const SizedBox(height: FgTokens.s4),

          // ── Net cash flow ───────────────────────────────────────────────
          ChartContainer(
            title: 'Net cash flow',
            isEmpty: netSeries.every((e) => e.$2 == 0),
            emptyMessage:
                'No transactions in this range yet — add income or expenses to see your flow.',
            textSummary: netSeries.isEmpty
                ? 'No data.'
                : 'Latest ${cashGranularity.label.toLowerCase()} net '
                    '${money(netSeries.last.$2)}; range ${rangeLabel(netSeries)}.',
            chart: Column(children: [
              GranularityBar(
                selected: cashGranularity,
                onChanged: (g) =>
                    ref.read(cashFlowGranularityProvider.notifier).state = g,
              ),
              const SizedBox(height: FgTokens.s1),
              _RangeCaption(text: rangeLabel(netSeries)),
              const SizedBox(height: FgTokens.s2),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= netSeries.length) return const SizedBox.shrink();
                            // Label ~4 buckets to avoid crowding.
                            final step = (netSeries.length / 4).ceil().clamp(1, 99);
                            if (i % step != 0 && i != netSeries.length - 1) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _shortBucketLabel(netSeries[i].$1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          '${_shortBucketLabel(netSeries[group.x].$1)}\n${money(rod.toY.round())}',
                          theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < netSeries.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: netSeries[i].$2.toDouble(),
                            color: netSeries[i].$2 >= 0 ? FgTokens.success : FgTokens.error,
                            width: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FgTokens.s2),
              Text(
                'Net = income − expenses for each ${cashGranularity.label.toLowerCase()}.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(height: FgTokens.s4),

          // ── Expense trend + forecast ────────────────────────────────────
          ChartContainer(
            title: 'Expense trend & forecast',
            isEmpty: expenseSeries.every((e) => e.$2 == 0) &&
                expenseHistory.where((v) => v > 0).length < 3,
            emptyMessage:
                'Forecasting needs at least 3 ${trendGranularity.label.toLowerCase()}s of history — honest predictions only.',
            textSummary: forecast.insufficientData
                ? 'Insufficient data for a forecast at this granularity.'
                : 'Next ${trendGranularity.label.toLowerCase()} expected between '
                    '${money(forecast.points.first.lowMinor)} and '
                    '${money(forecast.points.first.highMinor)}. Confidence ${forecast.confidence}.',
            chart: Column(children: [
              GranularityBar(
                selected: trendGranularity,
                onChanged: (g) =>
                    ref.read(expenseTrendGranularityProvider.notifier).state = g,
              ),
              const SizedBox(height: FgTokens.s1),
              _RangeCaption(text: rangeLabel(expenseSeries)),
              const SizedBox(height: FgTokens.s2),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(money(s.y.round()),
                                theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      // Historical (solid)
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < expenseSeries.length; i++)
                            FlSpot(i.toDouble(), expenseSeries[i].$2.toDouble()),
                        ],
                        isCurved: true,
                        color: FgTokens.cyan,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData:
                            BarAreaData(show: true, color: FgTokens.cyan.withValues(alpha: 0.12)),
                      ),
                      // Forecast (dashed) — clearly distinct from history
                      if (!forecast.insufficientData)
                        LineChartBarData(
                          spots: [
                            FlSpot((expenseSeries.length - 1).toDouble(),
                                expenseSeries.last.$2.toDouble()),
                            for (final p in forecast.points)
                              FlSpot((expenseSeries.length - 1 + p.periodIndex).toDouble(),
                                  p.expectedMinor.toDouble()),
                          ],
                          isCurved: false,
                          color: FgTokens.gold,
                          barWidth: 2,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: true),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FgTokens.s2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legendSwatch(FgTokens.cyan, 'History', theme),
                const SizedBox(width: FgTokens.s4),
                _legendSwatch(FgTokens.gold, 'Forecast (dashed)', theme),
              ]),
            ]),
          ),
          if (backtest.isNotEmpty) ...[
            const SizedBox(height: FgTokens.s4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(FgTokens.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How accurate were past forecasts?',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: FgTokens.s2),
                    for (final (predicted, actual) in backtest.reversed.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: FgTokens.s1),
                        child: Text('Predicted ${money(predicted)} → actual ${money(actual)}',
                            style: theme.textTheme.bodySmall),
                      ),
                    Text('We show this so you can judge the model for yourself.',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: FgTokens.s4),

          // ── Budget vs actual (monthly by definition) ────────────────────
          ChartContainer(
            title: 'Budget vs actual',
            isEmpty: budgetRows.isEmpty,
            emptyMessage:
                'No budgets for ${Dates.monthLabel(budgetKey)}. Create budgets in Plans → Budgets.',
            textSummary: budgetRows.isEmpty
                ? 'No budgets.'
                : '${budgetRows.where((r) => r.$2 > r.$1.limitMinor).length} of '
                    '${budgetRows.length} budgets over limit in ${Dates.monthLabel(budgetKey)}.',
            tableAlternative: Column(children: [
              for (final (b, spent) in budgetRows)
                ListTile(
                  dense: true,
                  title: Text(b.categoryId),
                  trailing: Text('${money(spent)} / ${money(b.limitMinor)}'),
                ),
            ]),
            chart: Column(children: [
              Row(children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(budgetReportMonthProvider.notifier).state =
                      Dates.addMonths(budgetMonth, -1),
                ),
                Expanded(
                  child: Text(Dates.monthLabel(budgetKey),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: Dates.periodKey(budgetMonth) == Dates.periodKey(DateTime.now())
                      ? null
                      : () => ref.read(budgetReportMonthProvider.notifier).state =
                          Dates.addMonths(budgetMonth, 1),
                ),
              ]),
              const SizedBox(height: FgTokens.s2),
              for (final (b, spent) in budgetRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: FgTokens.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(b.categoryId, style: theme.textTheme.labelMedium)),
                        Text('${money(spent)} / ${money(b.limitMinor)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: spent > b.limitMinor
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: FgTokens.s1),
                      LinearProgressIndicator(
                        value: b.limitMinor <= 0
                            ? 0
                            : (spent / b.limitMinor).clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(FgTokens.rPill),
                        color: spent > b.limitMinor
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ]),
          ),
          const SizedBox(height: FgTokens.s10),
        ],
      ),
    );
  }

  static String _shortBucketLabel(Period p) => switch (p.granularity) {
        PeriodGranularity.day => DateFormat('d/M').format(p.start),
        PeriodGranularity.week => DateFormat('d/M').format(p.start),
        PeriodGranularity.month => DateFormat('MMM').format(p.start),
        PeriodGranularity.year => DateFormat('yyyy').format(p.start),
      };

  Widget _legendSwatch(Color color, String label, ThemeData theme) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: FgTokens.s1),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]);
}

// The Day/Week/Month/Year selector now lives in
// features/transactions/presentation/granularity_bar.dart so the dashboard
// breakdown and every report chart share one implementation.

class _RangeCaption extends StatelessWidget {
  const _RangeCaption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.center,
      child: Text(text,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
