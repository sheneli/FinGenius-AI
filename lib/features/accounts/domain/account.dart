enum AccountType { cash, bank, card, wallet, savings }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceMinor,
    required this.currency,
    this.archived = false,
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final AccountType type;
  final int balanceMinor;
  final String currency;
  final bool archived;
  final int schemaVersion;

  bool get isLiquid =>
      type == AccountType.cash ||
      type == AccountType.bank ||
      type == AccountType.wallet ||
      type == AccountType.savings;

  Account copyWith(
          {String? name,
          AccountType? type,
          int? balanceMinor,
          bool? archived}) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        balanceMinor: balanceMinor ?? this.balanceMinor,
        currency: currency,
        archived: archived ?? this.archived,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'balanceMinor': balanceMinor,
        'currency': currency,
        'archived': archived,
        'schemaVersion': schemaVersion,
      };

  static Account fromMap(String id, Map<String, dynamic> m) => Account(
        id: id,
        name: (m['name'] as String?) ?? 'Account',
        type: AccountType.values.byName((m['type'] as String?) ?? 'cash'),
        balanceMinor: (m['balanceMinor'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'LKR',
        archived: (m['archived'] as bool?) ?? false,
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
