enum BillRecurrence { weekly, monthly, yearly }

class Bill {
  const Bill({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.categoryId,
    required this.recurrence,
    required this.anchorDate,
    required this.nextDueAt,
    this.autopay = false,
    this.lastPaidAt,
    this.fromSubscriptionId,
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final int amountMinor;
  final String currency;
  final String categoryId;
  final BillRecurrence recurrence;
  final DateTime anchorDate;
  final DateTime nextDueAt;
  final bool autopay;
  final DateTime? lastPaidAt;
  final String? fromSubscriptionId;
  final int schemaVersion;

  bool get isOverdue => DateTime.now().isAfter(nextDueAt) &&
      (lastPaidAt == null || lastPaidAt!.isBefore(nextDueAt));

  DateTime nextOccurrenceAfter(DateTime from) => switch (recurrence) {
        BillRecurrence.weekly => from.add(const Duration(days: 7)),
        BillRecurrence.monthly => DateTime(from.year, from.month + 1, anchorDate.day.clamp(1, 28)),
        BillRecurrence.yearly => DateTime(from.year + 1, from.month, from.day),
      };

  /// Upcoming due dates of this bill that fall inside [month], projecting the
  /// recurrence forward from [nextDueAt] across month/year boundaries.
  /// Months entirely before the next due date yield nothing — past
  /// occurrences are history (paid or missed), not projections.
  List<DateTime> occurrencesInMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonthStart = DateTime(month.year, month.month + 1);
    final out = <DateTime>[];
    var d = nextDueAt;
    var guard = 0;
    while (d.isBefore(nextMonthStart) && guard++ < 62) {
      if (!d.isBefore(monthStart)) out.add(DateTime(d.year, d.month, d.day));
      final advanced = nextOccurrenceAfter(d);
      // A non-advancing recurrence would loop forever; bail out defensively.
      if (!advanced.isAfter(d)) break;
      d = advanced;
    }
    return out;
  }

  Bill markPaid(DateTime when) => Bill(
        id: id, name: name, amountMinor: amountMinor, currency: currency,
        categoryId: categoryId, recurrence: recurrence, anchorDate: anchorDate,
        nextDueAt: nextOccurrenceAfter(nextDueAt), autopay: autopay,
        lastPaidAt: when, fromSubscriptionId: fromSubscriptionId, schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'name': name, 'amountMinor': amountMinor, 'currency': currency,
        'categoryId': categoryId, 'recurrence': recurrence.name,
        'anchorDate': anchorDate.toUtc().toIso8601String(),
        'nextDueAt': nextDueAt.toUtc().toIso8601String(),
        'autopay': autopay,
        'lastPaidAt': lastPaidAt?.toUtc().toIso8601String(),
        'fromSubscriptionId': fromSubscriptionId,
        'schemaVersion': schemaVersion,
      };

  static Bill fromMap(String id, Map<String, dynamic> m) => Bill(
        id: id,
        name: (m['name'] as String?) ?? 'Bill',
        amountMinor: (m['amountMinor'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'LKR',
        categoryId: (m['categoryId'] as String?) ?? 'utilities',
        recurrence: BillRecurrence.values.byName((m['recurrence'] as String?) ?? 'monthly'),
        anchorDate: DateTime.tryParse((m['anchorDate'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        nextDueAt: DateTime.tryParse((m['nextDueAt'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        autopay: (m['autopay'] as bool?) ?? false,
        lastPaidAt: DateTime.tryParse((m['lastPaidAt'] as String?) ?? '')?.toLocal(),
        fromSubscriptionId: m['fromSubscriptionId'] as String?,
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
