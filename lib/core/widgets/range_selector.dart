import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Time ranges available across charts and reports.
enum ChartRange { day, week, month, year }

extension ChartRangeX on ChartRange {
  String get label => switch (this) {
        ChartRange.day => 'Day',
        ChartRange.week => 'Week',
        ChartRange.month => 'Month',
        ChartRange.year => 'Year',
      };

  /// Inclusive start of the window ending now.
  DateTime start([DateTime? now]) {
    final n = now ?? DateTime.now();
    return switch (this) {
      ChartRange.day => DateTime(n.year, n.month, n.day).subtract(const Duration(days: 6)),
      ChartRange.week => DateTime(n.year, n.month, n.day).subtract(const Duration(days: 7 * 7)),
      ChartRange.month => DateTime(n.year, n.month - 11, 1),
      ChartRange.year => DateTime(n.year - 4, 1, 1),
    };
  }

  /// Bucket key for grouping a date within this range.
  String bucketOf(DateTime d) => switch (this) {
        ChartRange.day => '${d.year}-${_2(d.month)}-${_2(d.day)}',
        ChartRange.week => _isoWeekKey(d),
        ChartRange.month => '${d.year}-${_2(d.month)}',
        ChartRange.year => '${d.year}',
      };

  static String _2(int v) => v.toString().padLeft(2, '0');

  static String _isoWeekKey(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)));
    final firstDay = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${_2(week)}';
  }
}

/// Pill-style range switcher (Spendly-inspired chips).
class RangeSelector extends StatelessWidget {
  const RangeSelector({super.key, required this.value, required this.onChanged});
  final ChartRange value;
  final ValueChanged<ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final r in ChartRange.values)
            Padding(
              padding: const EdgeInsets.only(right: FgTokens.s2),
              child: ChoiceChip(
                label: Text(r.label),
                selected: r == value,
                onSelected: (_) => onChanged(r),
                showCheckmark: false,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: r == value ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FgTokens.rPill),
                  side: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
