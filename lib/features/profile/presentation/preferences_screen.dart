import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/analytics/analytics_service.dart';

/// Theme, currency, payday, quiet hours, and privacy consents in one place.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  Future<void> _setPref(WidgetRef ref, Map<String, dynamic> patch) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(firestoreProvider).doc('users/$uid').set({'prefs': patch}, SetOptions(merge: true));
  }

  /// Persists a consent change.
  ///
  /// Bounded on purpose: `set()` does not complete until the server
  /// acknowledges, so awaiting it bare left the switch spinning indefinitely
  /// whenever Firestore was unreachable. A timeout is not data loss — the write
  /// is already in the SDK's offline cache and the local snapshot listener has
  /// already reported it, so the toggle reflects the new value either way.
  static Future<void> _setConsent(WidgetRef ref, Map<String, dynamic> patch) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      await ref.read(firestoreProvider).doc('users/$uid').set({
        'consent': {...patch, 'acceptedAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('consent change queued locally: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final prefs = profile?.prefs;
    final consent = profile?.consent;

    String minutesLabel(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(FgTokens.s4),
        children: [
          Text('Appearance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FgTokens.s2),
          Card(
            child: Column(children: [
              RadioListTile<String>(
                title: const Text('Dark (default)'),
                value: 'dark',
                groupValue: prefs?.theme ?? 'dark',
                onChanged: (v) => _setPref(ref, {'theme': v}),
              ),
              RadioListTile<String>(
                title: const Text('Light'),
                value: 'light',
                groupValue: prefs?.theme ?? 'dark',
                onChanged: (v) => _setPref(ref, {'theme': v}),
              ),
              RadioListTile<String>(
                title: const Text('Follow system'),
                value: 'system',
                groupValue: prefs?.theme ?? 'dark',
                onChanged: (v) => _setPref(ref, {'theme': v}),
              ),
            ]),
          ),
          const SizedBox(height: FgTokens.s5),
          Text('Money', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FgTokens.s2),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Currency'),
                trailing: DropdownButton<String>(
                  value: prefs?.currency ?? 'LKR',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'LKR', child: Text('LKR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'INR', child: Text('INR')),
                  ],
                  onChanged: (v) => _setPref(ref, {'currency': v}),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide balances by default'),
                value: prefs?.hideBalances ?? false,
                onChanged: (v) => _setPref(ref, {'hideBalances': v}),
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Payday (day of month)'),
                subtitle: const Text('Powers payday-aware nudges'),
                trailing: DropdownButton<int?>(
                  value: prefs?.paydayDay,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Not set')),
                    for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                  onChanged: (v) => _setPref(ref, {'paydayDay': v}),
                ),
              ),
            ]),
          ),
          const SizedBox(height: FgTokens.s5),
          Text('Quiet hours', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FgTokens.s2),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Start'),
                trailing: Text(minutesLabel(prefs?.quietStartMin ?? 1320)),
                onTap: () async {
                  final t = await showTimePicker(context: context,
                      initialTime: TimeOfDay(hour: (prefs?.quietStartMin ?? 1320) ~/ 60, minute: (prefs?.quietStartMin ?? 1320) % 60));
                  if (t != null) await _setPref(ref, {'quietStartMin': t.hour * 60 + t.minute});
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('End'),
                trailing: Text(minutesLabel(prefs?.quietEndMin ?? 450)),
                onTap: () async {
                  final t = await showTimePicker(context: context,
                      initialTime: TimeOfDay(hour: (prefs?.quietEndMin ?? 450) ~/ 60, minute: (prefs?.quietEndMin ?? 450) % 60));
                  if (t != null) await _setPref(ref, {'quietEndMin': t.hour * 60 + t.minute});
                },
              ),
            ]),
          ),
          const SizedBox(height: FgTokens.s5),
          Text('Privacy & consent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FgTokens.s2),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('AI processing'),
                subtitle: const Text('Lets the assistant analyse aggregated totals. Raw transactions are never shared.'),
                value: consent?.aiProcessing ?? false,
                onChanged: (v) => _setConsent(ref, {'aiProcessing': v}),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.analytics_outlined),
                title: const Text('Anonymous usage analytics'),
                subtitle: const Text('Feature-usage counts only — never amounts, merchants or notes.'),
                value: consent?.analytics ?? false,
                onChanged: (v) async {
                  await _setConsent(ref, {'analytics': v});
                  await ref.read(analyticsProvider).setConsent(granted: v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifications'),
                subtitle: const Text('Bill reminders, budget alerts and nudges'),
                value: consent?.notifications ?? false,
                onChanged: (v) => _setConsent(ref, {'notifications': v}),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
