class GoalContribution {
  const GoalContribution(this.amountMinor, this.at, {this.note = ''});
  final int amountMinor;
  final DateTime at;
  final String note;

  Map<String, dynamic> toMap() => {'amountMinor': amountMinor, 'at': at.toUtc().toIso8601String(), 'note': note};
  static GoalContribution fromMap(Map<String, dynamic> m) => GoalContribution(
        (m['amountMinor'] as num?)?.toInt() ?? 0,
        DateTime.tryParse((m['at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        note: (m['note'] as String?) ?? '',
      );
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.savedMinor,
    required this.currency,
    this.deadline,
    this.iconKey = 'flag',
    this.archived = false,
    this.contributions = const [],
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final int targetMinor;
  final int savedMinor;
  final String currency;
  final DateTime? deadline;
  final String iconKey;
  final bool archived;
  final List<GoalContribution> contributions;
  final int schemaVersion;

  double get progress => targetMinor <= 0 ? 0 : (savedMinor / targetMinor).clamp(0.0, 1.0);
  int get remainingMinor => (targetMinor - savedMinor).clamp(0, targetMinor);

  /// Honest projection from actual contribution pace. Returns null when there
  /// is not enough history to say anything meaningful.
  DateTime? projectedCompletion({DateTime? now}) {
    if (savedMinor >= targetMinor) return now ?? DateTime.now();
    if (contributions.length < 2) return null;
    final sorted = [...contributions]..sort((a, b) => a.at.compareTo(b.at));
    final spanDays = sorted.last.at.difference(sorted.first.at).inDays;
    if (spanDays < 7) return null;
    // The first contribution opens the observation window; the pace across
    // [first..last] is what arrived AFTER it. Counting it too would
    // overestimate pace (3 contributions span only 2 intervals).
    final total = sorted.skip(1).fold<int>(0, (s, c) => s + c.amountMinor);
    final perDay = total / spanDays;
    if (perDay <= 0) return null;
    final daysLeft = (remainingMinor / perDay).ceil();
    if (daysLeft > 365 * 20) return null; // beyond meaningful horizon
    return (now ?? DateTime.now()).add(Duration(days: daysLeft));
  }

  Goal copyWith({String? name, int? targetMinor, int? savedMinor, DateTime? deadline, bool? archived, List<GoalContribution>? contributions}) => Goal(
        id: id,
        name: name ?? this.name,
        targetMinor: targetMinor ?? this.targetMinor,
        savedMinor: savedMinor ?? this.savedMinor,
        currency: currency,
        deadline: deadline ?? this.deadline,
        iconKey: iconKey,
        archived: archived ?? this.archived,
        contributions: contributions ?? this.contributions,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'targetMinor': targetMinor,
        'savedMinor': savedMinor,
        'currency': currency,
        'deadline': deadline?.toUtc().toIso8601String(),
        'iconKey': iconKey,
        'archived': archived,
        'contributions': contributions.take(200).map((c) => c.toMap()).toList(),
        'schemaVersion': schemaVersion,
      };

  static Goal fromMap(String id, Map<String, dynamic> m) => Goal(
        id: id,
        name: (m['name'] as String?) ?? 'Goal',
        targetMinor: (m['targetMinor'] as num?)?.toInt() ?? 0,
        savedMinor: (m['savedMinor'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'LKR',
        deadline: DateTime.tryParse((m['deadline'] as String?) ?? '')?.toLocal(),
        iconKey: (m['iconKey'] as String?) ?? 'flag',
        archived: (m['archived'] as bool?) ?? false,
        contributions: ((m['contributions'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(GoalContribution.fromMap)
            .toList(),
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
