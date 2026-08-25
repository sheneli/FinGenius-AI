import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../domain/bill.dart';

final billsStreamProvider = StreamProvider<List<Bill>>((ref) {
  final repo = ref.watch(billsRepoProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll().map((b) => b..sort((x, y) => x.nextDueAt.compareTo(y.nextDueAt)));
});

/// Bills due within the next 14 days.
final upcomingBillsProvider = Provider<List<Bill>>((ref) {
  final bills = ref.watch(billsStreamProvider).valueOrNull ?? const <Bill>[];
  final cutoff = DateTime.now().add(const Duration(days: 14));
  return bills.where((b) => b.nextDueAt.isBefore(cutoff)).toList();
});

/// (paidOnTime, due) over the trailing 90 days — feeds the health score.
final billPunctualityProvider = Provider<(int paidOnTime, int due)>((ref) {
  final bills = ref.watch(billsStreamProvider).valueOrNull ?? const <Bill>[];
  final since = DateTime.now().subtract(const Duration(days: 90));
  var due = 0, onTime = 0;
  for (final b in bills) {
    if (b.lastPaidAt != null && b.lastPaidAt!.isAfter(since)) {
      due++;
      // Paid before/at the due date it satisfied.
      if (!b.lastPaidAt!.isAfter(b.nextDueAt)) onTime++;
      // Heuristic: nextDueAt advanced past lastPaidAt means it was settled.
      if (b.nextDueAt.isAfter(b.lastPaidAt!)) onTime = onTime.clamp(0, due);
    } else if (b.isOverdue) {
      due++;
    }
  }
  return (onTime, due);
});
