import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// GDPR-style data export: everything the user owns, as JSON or CSV,
/// generated on-device and handed to the system share sheet.
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  bool _busy = false;

  Future<void> _export(String format) async {
    setState(() => _busy = true);
    try {
      final txs = ref.read(transactionsStreamProvider).valueOrNull ?? [];
      final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
      final goals = ref.read(goalsStreamProvider).valueOrNull ?? [];
      final budgets = ref.read(budgetsStreamProvider).valueOrNull ?? [];
      final profile = ref.read(userProfileProvider).valueOrNull;

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      late final File file;

      if (format == 'json') {
        final payload = {
          'exportedAt': DateTime.now().toIso8601String(),
          'app': 'FinGenius AI',
          'profile': {'email': profile?.email, 'displayName': profile?.displayName},
          'accounts': accounts.map((a) => a.toMap()).toList(),
          'transactions': txs.map((t) => t.toMap()).toList(),
          'budgets': budgets.map((b) => b.toMap()).toList(),
          'goals': goals.map((g) => g.toMap()).toList(),
        };
        file = File('${dir.path}/fingenius_export_$stamp.json');
        await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      } else {
        final rows = <List<dynamic>>[
          ['date', 'type', 'amount', 'currency', 'category', 'merchant', 'note', 'account'],
          for (final t in txs)
            [
              t.occurredAt.toIso8601String().substring(0, 10),
              t.type.name,
              (t.amountMinor / 100).toStringAsFixed(2),
              t.currency,
              t.categoryId,
              t.merchant,
              t.note,
              t.accountId,
            ],
        ];
        file = File('${dir.path}/fingenius_transactions_$stamp.csv');
        await file.writeAsString(const ListToCsvConverter().convert(rows));
      }

      await ref.read(analyticsProvider).log(AnalyticsService.exportRequested, {'format': format});
      await Share.shareXFiles([XFile(file.path)], subject: 'FinGenius AI data export');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export my data')),
      body: ListView(
        padding: const EdgeInsets.all(FgTokens.s6),
        children: [
          Icon(Icons.download_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: FgTokens.s4),
          Text('Your data belongs to you',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: FgTokens.s2),
          Text(
            'Export everything stored in your account. Files are generated on this device '
            'and shared through Android — nothing extra is sent to our servers.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FgTokens.s8),
          FilledButton.icon(
            onPressed: _busy ? null : () => _export('json'),
            icon: const Icon(Icons.data_object),
            label: const Text('Export everything (JSON)'),
          ),
          const SizedBox(height: FgTokens.s3),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _export('csv'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export transactions (CSV)'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: FgTokens.s6),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
