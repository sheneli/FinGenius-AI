import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/feature_flags.dart';
import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/states.dart';
import '../../bills/domain/bill.dart';
import '../../insights/domain/subscription_detector.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Detected recurring payments. Candidates require user confirmation —
/// confirming creates a tracked bill; dismissing records the correction.
final subscriptionCandidatesProvider = Provider<List<SubscriptionCandidate>>((ref) {
  if (!ref.watch(featureFlagsProvider).subscriptionDetection) return const [];
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  final dismissed = ref.watch(_dismissedProvider);
  return const SubscriptionDetector()
      .detect(txs)
      .where((c) => !dismissed.contains(c.normalizedMerchant))
      .toList();
});

final _dismissedProvider = StateProvider<Set<String>>((_) => {});

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final candidates = ref.watch(subscriptionCandidatesProvider);
    final txsAsync = ref.watch(transactionsStreamProvider);
    final currency = ref.watch(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: AsyncValueView(
        value: txsAsync,
        onRetry: () => ref.invalidate(transactionsStreamProvider),
        data: (_) {
          if (candidates.isEmpty) {
            return const EmptyState(
              icon: Icons.subscriptions_outlined,
              title: 'Nothing detected yet',
              message: 'When the same merchant charges you regularly (3+ times at a steady interval), '
                  'it will appear here for you to confirm or dismiss.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(FgTokens.s4),
            children: [
              Text(
                'These look like recurring payments. Confirm to track them as bills, or dismiss.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: FgTokens.s3),
              for (final c in candidates)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FgTokens.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(c.merchant,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          AmountText(Money(c.amountMinor, currency)),
                        ]),
                        const SizedBox(height: FgTokens.s1),
                        Text(
                          'Every ~${c.intervalDays} days · confidence ${(c.confidence * 100).round()}% '
                          '· based on ${c.evidenceTxIds.length} transactions',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: FgTokens.s3),
                        Row(children: [
                          FilledButton.tonal(
                            onPressed: () async {
                              final repo = ref.read(billsRepoProvider);
                              if (repo == null) return;
                              await repo.upsert(Bill(
                                id: '',
                                name: c.merchant,
                                amountMinor: c.amountMinor,
                                currency: currency,
                                categoryId: 'entertainment',
                                recurrence: c.intervalDays <= 10
                                    ? BillRecurrence.weekly
                                    : c.intervalDays >= 300
                                        ? BillRecurrence.yearly
                                        : BillRecurrence.monthly,
                                anchorDate: c.nextExpected,
                                nextDueAt: c.nextExpected,
                              ));
                              ref.read(_dismissedProvider.notifier).update((s) => {...s, c.normalizedMerchant});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${c.merchant} is now tracked as a bill.')),
                                );
                              }
                            },
                            child: const Text('Confirm'),
                          ),
                          const SizedBox(width: FgTokens.s2),
                          TextButton(
                            onPressed: () => ref
                                .read(_dismissedProvider.notifier)
                                .update((s) => {...s, c.normalizedMerchant}),
                            child: const Text('Dismiss'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
