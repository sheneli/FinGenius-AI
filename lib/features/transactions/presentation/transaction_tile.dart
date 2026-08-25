import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/fintech.dart';
import '../domain/category.dart';
import '../domain/transaction_entry.dart';

/// Reusable transaction row with category icon, pending-sync badge, and
/// full screen-reader semantics.
class TransactionTile extends StatelessWidget {
  const TransactionTile(
      {super.key, required this.tx, this.category, this.onTap});

  final TransactionEntry tx;
  final Category? category;
  final VoidCallback? onTap;

  static const _icons = <String, IconData>{
    'cart': Icons.shopping_cart_outlined,
    'restaurant': Icons.restaurant_outlined,
    'car': Icons.directions_car_outlined,
    'bolt': Icons.bolt_outlined,
    'home': Icons.home_outlined,
    'heart': Icons.favorite_outline,
    'movie': Icons.movie_outlined,
    'bag': Icons.shopping_bag_outlined,
    'school': Icons.school_outlined,
    'shield': Icons.shield_outlined,
    'category': Icons.category_outlined,
    'work': Icons.work_outline,
    'laptop': Icons.laptop_outlined,
    'trending': Icons.trending_up,
    'plus': Icons.add_circle_outline,
    'flag': Icons.flag_outlined,
    'swap': Icons.swap_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = tx.type == TxType.expense;
    final money = Money(tx.signedMinor, tx.currency);
    final colorIndex = int.tryParse(category?.colorKey ?? '') ?? 0;
    final catColor =
        FgTokens.chartPalette[colorIndex % FgTokens.chartPalette.length];
    final title = tx.merchant.isNotEmpty
        ? tx.merchant
        : (category?.name ?? 'Transaction');

    return FinListRow(
      icon: _icons[category?.iconKey] ?? Icons.category_outlined,
      iconTint: catColor,
      title: title,
      subtitle:
          '${category?.name ?? tx.categoryId} · ${Dates.friendly(tx.occurredAt)}',
      onTap: onTap,
      badge: tx.pendingSync
          ? Icon(Icons.sync,
              size: FgTokens.iconSm, color: theme.colorScheme.onSurfaceVariant)
          : null,
      semanticLabel: '${isExpense ? 'Expense' : 'Income'}: $title, '
          '${money.abs().format()}, ${Dates.friendly(tx.occurredAt)}'
          '${tx.pendingSync ? ', waiting to sync' : ''}',
      trailing: AmountText(
        money,
        signed: true,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: isExpense ? theme.colorScheme.onSurface : FgTokens.success,
        ),
      ),
    );
  }
}
