import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/widgets/brand_mark.dart';

/// Biometric gate shown at launch and on resume while app-lock is enabled.
///
/// Every [AuthOutcome] gets its own message and its own next step. The one that
/// matters most is [AuthOutcome.notEnrolled]: if the user removes their
/// fingerprints and has no device PIN, nothing can ever satisfy the prompt, so
/// the screen offers to turn the lock off rather than trapping them outside
/// their own data.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  AuthOutcome? _last;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // One automatic attempt on arrival; afterwards the user drives it, so a
    // repeated failure can never become a prompt loop.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref.read(appLockedProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = outcome;
    });
    // On success the router redirects away as soon as the lock clears; no
    // explicit navigation here, so there is one source of truth for routing.
  }

  Future<void> _turnLockOff() async {
    await ref.read(appLockedProvider.notifier).disableAndUnlock();
  }

  ({String message, String action, bool offerDisable}) _explain(
      AuthOutcome outcome) {
    return switch (outcome) {
      AuthOutcome.success => (
          message: 'Unlocked.',
          action: 'Continue',
          offerDisable: false
        ),
      AuthOutcome.failed => (
          message: "That didn't match. Try again, or use your device PIN.",
          action: 'Try again',
          offerDisable: false
        ),
      AuthOutcome.canceled => (
          message: 'Unlock to continue.',
          action: 'Unlock',
          offerDisable: false
        ),
      AuthOutcome.lockedOut => (
          message: 'Too many attempts. Wait about 30 seconds, then try again.',
          action: 'Try again',
          offerDisable: false
        ),
      AuthOutcome.permanentlyLockedOut => (
          message: 'Biometrics are locked. Unlock your device with its PIN or '
              'password first, then come back.',
          action: 'Try again',
          offerDisable: false
        ),
      AuthOutcome.notEnrolled => (
          message: 'This device no longer has a fingerprint, face or PIN set '
              'up, so the app lock cannot be used.',
          action: 'Try again',
          offerDisable: true
        ),
      AuthOutcome.unavailable => (
          message: 'Authentication is unavailable on this device right now.',
          action: 'Try again',
          offerDisable: true
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = _last;
    final detail = outcome == null ? null : _explain(outcome);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(FgTokens.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: 88),
                const SizedBox(height: FgTokens.s6),
                Text('FinGenius AI is locked',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: FgTokens.s2),
                Text(
                  detail?.message ??
                      'Unlock with your fingerprint, face or device PIN',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: FgTokens.s8),
                FilledButton.icon(
                  onPressed: _busy ? null : _attempt,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fingerprint),
                  label: Text(_busy ? 'Waiting…' : (detail?.action ?? 'Unlock')),
                ),
                if (detail?.offerDisable ?? false) ...[
                  const SizedBox(height: FgTokens.s3),
                  TextButton(
                    onPressed: _busy ? null : _turnLockOff,
                    child: const Text('Turn off app lock and continue'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
