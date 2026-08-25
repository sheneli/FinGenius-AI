class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.periodKey,
    required this.limitMinor,
    required this.currency,
    this.alert80Sent = false,
    this.alert100Sent = false,
    this.schemaVersion = 1,
  });

  final String id;
  final String categoryId;
  final String periodKey; // YYYY-MM
  final int limitMinor;
  final String currency;
  final bool alert80Sent;
  final bool alert100Sent;
  final int schemaVersion;

  Budget copyWith({int? limitMinor, bool? alert80Sent, bool? alert100Sent}) => Budget(
        id: id,
        categoryId: categoryId,
        periodKey: periodKey,
        limitMinor: limitMinor ?? this.limitMinor,
        currency: currency,
        alert80Sent: alert80Sent ?? this.alert80Sent,
        alert100Sent: alert100Sent ?? this.alert100Sent,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'periodKey': periodKey,
        'limitMinor': limitMinor,
        'currency': currency,
        'alert80Sent': alert80Sent,
        'alert100Sent': alert100Sent,
        'schemaVersion': schemaVersion,
      };

  static Budget fromMap(String id, Map<String, dynamic> m) => Budget(
        id: id,
        categoryId: (m['categoryId'] as String?) ?? 'other',
        periodKey: (m['periodKey'] as String?) ?? '',
        limitMinor: (m['limitMinor'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'LKR',
        alert80Sent: (m['alert80Sent'] as bool?) ?? false,
        alert100Sent: (m['alert100Sent'] as bool?) ?? false,
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}

/// Budget + computed spend (derived client-side from transactions).
class BudgetProgress {
  const BudgetProgress(this.budget, this.spentMinor);
  final Budget budget;
  final int spentMinor;
  double get ratio => budget.limitMinor <= 0 ? 0 : spentMinor / budget.limitMinor;
  bool get over => spentMinor > budget.limitMinor;
}
