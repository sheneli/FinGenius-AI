import 'package:intl/intl.dart';

import 'transaction_entry.dart';

/// Time granularities offered by spending-breakdown and report filters.
enum PeriodGranularity { day, week, month, year }

extension PeriodGranularityLabel on PeriodGranularity {
  String get label => switch (this) {
        PeriodGranularity.day => 'Day',
        PeriodGranularity.week => 'Week',
        PeriodGranularity.month => 'Month',
        PeriodGranularity.year => 'Year',
      };
}

/// A concrete local-time period (one day, one Monday-based week, one month or
/// one year). All boundary maths uses local `DateTime`s built from date
/// components only, so daylight/timezone shifts cannot cause off-by-one-day
/// bugs.
class Period {
  Period._(this.granularity, this.start, this.endExclusive);

  final PeriodGranularity granularity;
  final DateTime start; // inclusive, local midnight
  final DateTime endExclusive; // exclusive, local midnight

  /// The period of [granularity] containing [when].
  factory Period.containing(DateTime when, PeriodGranularity granularity) {
    final d = DateTime(when.year, when.month, when.day);
    switch (granularity) {
      case PeriodGranularity.day:
        return Period._(granularity, d, DateTime(d.year, d.month, d.day + 1));
      case PeriodGranularity.week:
        // Weeks start on Monday, matching the bills calendar header.
        final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        return Period._(granularity, monday,
            DateTime(monday.year, monday.month, monday.day + 7));
      case PeriodGranularity.month:
        return Period._(granularity, DateTime(d.year, d.month),
            DateTime(d.year, d.month + 1));
      case PeriodGranularity.year:
        return Period._(
            granularity, DateTime(d.year), DateTime(d.year + 1));
    }
  }

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(endExclusive);

  Period previous() => switch (granularity) {
        PeriodGranularity.day => Period.containing(
            DateTime(start.year, start.month, start.day - 1), granularity),
        PeriodGranularity.week => Period.containing(
            DateTime(start.year, start.month, start.day - 7), granularity),
        PeriodGranularity.month => Period.containing(
            DateTime(start.year, start.month - 1), granularity),
        PeriodGranularity.year =>
          Period.containing(DateTime(start.year - 1), granularity),
      };

  Period next() => switch (granularity) {
        PeriodGranularity.day ||
        PeriodGranularity.week =>
          Period.containing(endExclusive, granularity),
        PeriodGranularity.month => Period.containing(
            DateTime(start.year, start.month + 1), granularity),
        PeriodGranularity.year =>
          Period.containing(DateTime(start.year + 1), granularity),
      };

  /// True when the period containing "now" is this period.
  bool get isCurrent => contains(DateTime.now());

  /// Human label, e.g. "Today", "This week", "Mon 14 – Sun 20 Jul",
  /// "July 2026", "2026".
  String label({DateTime? now}) {
    final ref = now ?? DateTime.now();
    switch (granularity) {
      case PeriodGranularity.day:
        final today = DateTime(ref.year, ref.month, ref.day);
        if (start == today) return 'Today';
        if (start == DateTime(today.year, today.month, today.day - 1)) {
          return 'Yesterday';
        }
        return DateFormat('EEE d MMM').format(start);
      case PeriodGranularity.week:
        if (contains(ref)) return 'This week';
        final last = endExclusive.subtract(const Duration(days: 1));
        final sameMonth = start.month == last.month;
        final left = DateFormat(sameMonth ? 'd' : 'd MMM').format(start);
        return '$left – ${DateFormat('d MMM').format(last)}';
      case PeriodGranularity.month:
        if (contains(ref)) return 'This month';
        return DateFormat('MMMM yyyy').format(start);
      case PeriodGranularity.year:
        if (contains(ref)) return 'This year';
        return DateFormat('yyyy').format(start);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.granularity == granularity &&
      other.start == start;

  @override
  int get hashCode => Object.hash(granularity, start);
}

/// Aggregated totals for one [Period] — same shape as the monthly totals the
/// dashboard already uses, but for an arbitrary window.
class PeriodTotals {
  const PeriodTotals({
    required this.period,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.byCategory,
  });

  final Period period;
  final int incomeMinor;
  final int expenseMinor;
  final Map<String, int> byCategory; // categoryId -> expense minor

  int get netMinor => incomeMinor - expenseMinor;

  /// Aggregates only persisted transactions falling inside [period].
  /// Transfers are internal money movement and excluded, matching
  /// [monthTotalsProvider] semantics.
  static PeriodTotals compute(Iterable<TransactionEntry> txs, Period period) {
    var income = 0, expense = 0;
    final byCategory = <String, int>{};
    for (final t in txs) {
      if (!period.contains(t.occurredAt)) continue;
      if (t.categoryId == 'transfer') continue;
      if (t.type == TxType.income) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
        byCategory[t.categoryId] =
            (byCategory[t.categoryId] ?? 0) + t.amountMinor;
      }
    }
    return PeriodTotals(
      period: period,
      incomeMinor: income,
      expenseMinor: expense,
      byCategory: byCategory,
    );
  }

  /// Buckets net cash flow (or expenses only) for the trailing [count]
  /// periods ending with the one containing [anchor]; oldest first. Used by
  /// the report charts for every granularity.
  static List<(Period, int)> series(
    Iterable<TransactionEntry> txs, {
    required PeriodGranularity granularity,
    required int count,
    DateTime? anchor,
    bool expensesOnly = false,
  }) {
    var p = Period.containing(anchor ?? DateTime.now(), granularity);
    final periods = <Period>[p];
    for (var i = 1; i < count; i++) {
      p = p.previous();
      periods.insert(0, p);
    }
    return [
      for (final period in periods)
        (
          period,
          expensesOnly
              ? PeriodTotals.compute(txs, period).expenseMinor
              : PeriodTotals.compute(txs, period).netMinor,
        ),
    ];
  }
}
