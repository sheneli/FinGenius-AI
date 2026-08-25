import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/session_providers.dart';
import '../utils/money.dart';

/// Money display that honours the global "hide balances" preference.
/// Hidden values render as ••••• but keep real values out of semantics too.
class AmountText extends ConsumerWidget {
  const AmountText(this.money, {super.key, this.style, this.compact = false, this.signed = false});

  final Money money;
  final TextStyle? style;
  final bool compact;
  final bool signed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(userProfileProvider).valueOrNull?.prefs.hideBalances ?? false;
    if (hidden) {
      return Semantics(
        label: 'Balance hidden',
        child: Text('•••••', style: style),
      );
    }
    final prefix = signed && money.minor > 0 ? '+' : '';
    return Text('$prefix${money.format(compact: compact)}', style: style);
  }
}
