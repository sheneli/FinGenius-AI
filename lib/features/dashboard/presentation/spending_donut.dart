import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/chart_container.dart';
import '../../transactions/domain/category.dart';

/// Donut of this month's spending by category, with legend, tooltips,
/// a text summary for screen readers, and a table alternative.
class SpendingDonut extends StatefulWidget {
  const SpendingDonut({super.key, required this.byCategory, required this.categories, required this.currency});

  final Map<String, int> byCategory;
  final Map<String, Category> categories;
  final String currency;

  @override
  State<SpendingDonut> createState() => _SpendingDonutState();
}

class _SpendingDonutState extends State<SpendingDonut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final summary = entries.isEmpty
        ? 'No spending recorded this month.'
        : 'Total ${Money(total, widget.currency).format()}. Top categories: '
            '${entries.take(3).map((e) => '${widget.categories[e.key]?.name ?? e.key} ${Money(e.value, widget.currency).format(compact: true)}').join(', ')}.';

    Color colorFor(int i) => FgTokens.chartPalette[i % FgTokens.chartPalette.length];

    return ChartContainer(
      title: 'Spending breakdown',
      textSummary: summary,
      isEmpty: entries.isEmpty,
      tableAlternative: Column(children: [
        for (var i = 0; i < entries.length; i++)
          ListTile(
            dense: true,
            leading: Container(width: 12, height: 12,
                decoration: BoxDecoration(color: colorFor(i), shape: BoxShape.circle)),
            title: Text(widget.categories[entries[i].key]?.name ?? entries[i].key),
            trailing: Text(Money(entries[i].value, widget.currency).format()),
          ),
      ]),
      chart: Column(children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) => setState(
                  () => _touched = response?.touchedSection?.touchedSectionIndex,
                ),
              ),
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: colorFor(i),
                    radius: _touched == i ? 34 : 26,
                    showTitle: _touched == i,
                    title: Money(entries[i].value, widget.currency).format(compact: true),
                    titleStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
              ],
            ),
            duration: FgTokens.dMed,
          ),
        ),
        const SizedBox(height: FgTokens.s3),
        Wrap(
          spacing: FgTokens.s3,
          runSpacing: FgTokens.s1,
          children: [
            for (var i = 0; i < entries.length && i < 6; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: colorFor(i), shape: BoxShape.circle)),
                const SizedBox(width: FgTokens.s1),
                Text(widget.categories[entries[i].key]?.name ?? entries[i].key,
                    style: theme.textTheme.labelSmall),
              ]),
          ],
        ),
      ]),
    );
  }
}
