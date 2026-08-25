import '../../transactions/domain/transaction_entry.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.colorKey,
    this.isSeed = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final TxType kind;
  final String iconKey;
  final String colorKey; // index into FgTokens.chartPalette
  final bool isSeed;
  final int sortOrder;

  Map<String, dynamic> toMap() => {
        'name': name,
        'kind': kind.name,
        'iconKey': iconKey,
        'colorKey': colorKey,
        'isSeed': isSeed,
        'sortOrder': sortOrder,
      };

  static Category fromMap(String id, Map<String, dynamic> m) => Category(
        id: id,
        name: (m['name'] as String?) ?? 'Other',
        kind: TxType.values.byName((m['kind'] as String?) ?? 'expense'),
        iconKey: (m['iconKey'] as String?) ?? 'category',
        colorKey: (m['colorKey'] as String?) ?? '0',
        isSeed: (m['isSeed'] as bool?) ?? false,
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
      );

  /// Seed set created on first sign-in. IDs are stable (used by Categorizer).
  static const List<Category> seeds = [
    Category(id: 'groceries', name: 'Groceries', kind: TxType.expense, iconKey: 'cart', colorKey: '0', isSeed: true, sortOrder: 0),
    Category(id: 'dining', name: 'Dining out', kind: TxType.expense, iconKey: 'restaurant', colorKey: '1', isSeed: true, sortOrder: 1),
    Category(id: 'transport', name: 'Transport', kind: TxType.expense, iconKey: 'car', colorKey: '2', isSeed: true, sortOrder: 2),
    Category(id: 'utilities', name: 'Utilities', kind: TxType.expense, iconKey: 'bolt', colorKey: '3', isSeed: true, sortOrder: 3),
    Category(id: 'housing', name: 'Housing & rent', kind: TxType.expense, iconKey: 'home', colorKey: '4', isSeed: true, sortOrder: 4),
    Category(id: 'health', name: 'Health', kind: TxType.expense, iconKey: 'heart', colorKey: '5', isSeed: true, sortOrder: 5),
    Category(id: 'entertainment', name: 'Entertainment', kind: TxType.expense, iconKey: 'movie', colorKey: '6', isSeed: true, sortOrder: 6),
    Category(id: 'shopping', name: 'Shopping', kind: TxType.expense, iconKey: 'bag', colorKey: '7', isSeed: true, sortOrder: 7),
    Category(id: 'education', name: 'Education', kind: TxType.expense, iconKey: 'school', colorKey: '0', isSeed: true, sortOrder: 8),
    Category(id: 'insurance', name: 'Insurance', kind: TxType.expense, iconKey: 'shield', colorKey: '1', isSeed: true, sortOrder: 9),
    Category(id: 'other', name: 'Other', kind: TxType.expense, iconKey: 'category', colorKey: '2', isSeed: true, sortOrder: 10),
    // Both legs of an account transfer use this id; analytics exclude it so
    // moving money between your own accounts never counts as income/expense.
    Category(id: 'transfer', name: 'Transfers', kind: TxType.expense, iconKey: 'swap', colorKey: '3', isSeed: true, sortOrder: 11),
    Category(id: 'salary', name: 'Salary', kind: TxType.income, iconKey: 'work', colorKey: '1', isSeed: true, sortOrder: 0),
    Category(id: 'freelance', name: 'Freelance', kind: TxType.income, iconKey: 'laptop', colorKey: '0', isSeed: true, sortOrder: 1),
    Category(id: 'investment', name: 'Investment income', kind: TxType.income, iconKey: 'trending', colorKey: '2', isSeed: true, sortOrder: 2),
    Category(id: 'other_income', name: 'Other income', kind: TxType.income, iconKey: 'plus', colorKey: '3', isSeed: true, sortOrder: 3),
  ];
}
