import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';

/// Account deletion: explicit consequences → reauthentication → cloud doc
/// deletion request → auth deletion → local wipe. No silent failure paths.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final uid = ref.read(currentUidProvider);

    final reauth = await auth.reauthenticate(_password.text);
    if (!reauth.isOk) {
      setState(() {
        _busy = false;
        _error = reauth.failureOrNull?.message;
      });
      return;
    }

    try {
      // Delete the root user document. Full subtree cleanup is completed by
      // the operator-installed "Delete User Data" Firebase Extension —
      // documented in docs/setup/firebase_setup.md (no fake success claimed).
      if (uid != null) {
        await ref.read(firestoreProvider).doc('users/$uid').delete();
      }
      final result = await auth.deleteAccount();
      if (!result.isOk) {
        setState(() {
          _busy = false;
          _error = result.failureOrNull?.message;
        });
        return;
      }
      if (uid != null) {
        await ref.read(sessionCleanerProvider).onLogout(uid);
      }
      // Router redirect takes over once the auth state becomes null.
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Deletion failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FgTokens.s6),
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: FgTokens.s4),
            Text('This is permanent',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: FgTokens.s3),
            Text(
              'Deleting your account removes your profile, accounts, transactions, budgets, '
              'goals, bills, receipts and AI conversations. This cannot be undone.\n\n'
              'Consider exporting your data first (Profile → Export my data).',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FgTokens.s6),
            CheckboxListTile(
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I understand my data will be permanently deleted'),
            ),
            const SizedBox(height: FgTokens.s4),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm your password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: FgTokens.s3),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: FgTokens.s6),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              onPressed: !_confirmed || _password.text.isEmpty || _busy ? null : _delete,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Delete my account forever'),
            ),
            const SizedBox(height: FgTokens.s2),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Keep my account'),
            ),
          ],
        ),
      ),
    );
  }
}
