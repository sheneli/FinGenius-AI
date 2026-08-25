import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/biometric_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  LockAvailability? _availability;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Always re-reads secure storage rather than trusting local state, so the
  /// switch cannot drift from the value that actually governs the lock.
  Future<void> _load() async {
    final availability =
        await ref.read(biometricServiceProvider).availability();
    final enabled = await ref.read(appLockedProvider.notifier).isEnabled();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _enabled = enabled;
    });
  }

  String get _subtitle => switch (_availability) {
        LockAvailability.unsupported =>
          'This device does not support biometric or PIN authentication',
        LockAvailability.notEnrolled =>
          'Set up a fingerprint, face unlock or device PIN first, then enable this',
        _ => 'Require fingerprint, face or device PIN when the app opens',
      };

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final outcome =
        await ref.read(appLockedProvider.notifier).setEnabled(value);
    if (!mounted) return;
    setState(() => _busy = false);
    // Re-read storage: the switch reflects what was persisted, not what was
    // requested, so a refused authentication leaves it visibly off.
    await _load();
    if (!mounted) return;
    if (value && outcome != AuthOutcome.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (outcome) {
          AuthOutcome.canceled =>
            'App lock not enabled — authentication was cancelled.',
          AuthOutcome.notEnrolled =>
            'Set up a fingerprint, face unlock or device PIN in system settings first.',
          AuthOutcome.lockedOut || AuthOutcome.permanentlyLockedOut =>
            'Too many attempts. Unlock your device, then try again.',
          AuthOutcome.unavailable =>
            'Authentication is unavailable on this device.',
          _ => 'That did not match. App lock was not enabled.',
        }),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(FgTokens.s4),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric app lock'),
              subtitle: Text(_subtitle),
              value: _enabled,
              onChanged: _availability != LockAvailability.available || _busy
                  ? null
                  : _toggle,
            ),
          ),
          const SizedBox(height: FgTokens.s4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change password'),
              subtitle: const Text('A reset link is sent to your email'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final email = ref.read(authStateProvider).valueOrNull?.email;
                if (email == null) return;
                await ref.read(authRepositoryProvider).sendPasswordReset(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset link sent to $email')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: FgTokens.s4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FgTokens.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How your data is protected',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: FgTokens.s2),
                  Text(
                    '• All traffic uses HTTPS/TLS\n'
                    '• Cloud data is isolated per account by Firestore Security Rules\n'
                    '• App Check (Play Integrity) blocks tampered clients in production\n'
                    '• Sensitive local values live in Android encrypted storage\n'
                    '• Balance screens block screenshots and hide in Recents\n'
                    '• AI requests contain aggregated totals only — never raw transactions',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
