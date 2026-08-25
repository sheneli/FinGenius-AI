import 'package:intl/intl.dart';

/// Date helpers shared across budgets, reports and forecasting.
class Dates {
  Dates._();

  /// Canonical month key, e.g. `2026-07`.
  static String periodKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
  static DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1).subtract(const Duration(microseconds: 1));
  static DateTime addMonths(DateTime d, int months) => DateTime(d.year, d.month + months, 1);

  static String friendly(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return DateFormat.MMMd().format(d);
  }

  static String full(DateTime d) => DateFormat.yMMMMd().format(d);
  static String monthLabel(String periodKey) {
    final parts = periodKey.split('-');
    return DateFormat.yMMMM().format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
  }

  /// Days until [day]-of-month next occurs (payday awareness).
  static int daysUntilDayOfMonth(int day, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final thisMonth = DateTime(now.year, now.month, day.clamp(1, 28));
    final target = thisMonth.isBefore(DateTime(now.year, now.month, now.day))
        ? DateTime(now.year, now.month + 1, day.clamp(1, 28))
        : thisMonth;
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// True if [t] (minutes since midnight) falls inside quiet hours.
  static bool inQuietHours(int minutesOfDay, int startMin, int endMin) {
    if (startMin == endMin) return false;
    if (startMin < endMin) return minutesOfDay >= startMin && minutesOfDay < endMin;
    return minutesOfDay >= startMin || minutesOfDay < endMin; // spans midnight
  }
}
