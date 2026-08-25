import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/fintech.dart';
import '../../../core/widgets/states.dart';

class AppNotification {
  const AppNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.read,
      required this.createdAt});
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
}

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('users/$uid/notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => [
            for (final d in snap.docs)
              AppNotification(
                id: d.id,
                type: (d.data()['type'] as String?) ?? 'system',
                title: (d.data()['title'] as String?) ?? '',
                body: (d.data()['body'] as String?) ?? '',
                read: (d.data()['read'] as bool?) ?? false,
                createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ),
          ]);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(notificationsStreamProvider);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AsyncValueView(
        value: itemsAsync,
        onRetry: () => ref.invalidate(notificationsStreamProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message:
                  'Bill reminders, budget alerts and insights will land here. '
                  'Quiet hours are respected — configure them in Preferences.',
            );
          }
          // Unread first visually (unread carry a tinted icon + dot), but the
          // list order and read-marking behaviour are unchanged.
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                FgTokens.s4, FgTokens.s2, FgTokens.s4, FgTokens.s8),
            children: [
              RowGroup(children: [
                for (final n in items)
                  FinListRow(
                    icon: switch (n.type) {
                      'bill' => Icons.event_outlined,
                      'budget' => Icons.pie_chart_outline,
                      'nudge' => Icons.tips_and_updates_outlined,
                      'ai' => Icons.auto_awesome_outlined,
                      _ => Icons.notifications_none,
                    },
                    iconTint: n.read
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                    title: n.title,
                    subtitle: '${n.body}\n${Dates.friendly(n.createdAt)}',
                    semanticLabel:
                        '${n.read ? '' : 'Unread. '}${n.title}. ${n.body}. '
                        '${Dates.friendly(n.createdAt)}',
                    trailing: n.read
                        ? const SizedBox.shrink()
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: uid == null || n.read
                        ? null
                        : () => ref
                            .read(firestoreProvider)
                            .doc('users/$uid/notifications/${n.id}')
                            .set({'read': true}, SetOptions(merge: true)),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
