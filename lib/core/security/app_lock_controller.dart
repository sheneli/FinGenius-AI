import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_service.dart';

/// Owns whether the app is currently locked.
///
/// This is the piece that was missing. The lock preference was written to
/// secure storage and the router already redirected to `/lock` when a `locked`
/// flag was set — but nothing ever set it. The flag defaulted to false and the
/// only write in the whole app set it to false again, so the lock screen was
/// unreachable and the settings toggle changed nothing observable.
///
/// Two events must lock: cold start with the preference on, and returning to
/// the foreground after leaving it.
///
/// The subtlety is that the system biometric prompt *itself* pushes the app
/// through `inactive` → `paused` → `resumed`. Re-locking naively on every
/// resume means unlocking triggers another lock, forever. [_authInProgress]
/// suppresses lifecycle-driven locking for exactly as long as a prompt is up,
/// and [_graceWindow] additionally ignores momentary interruptions such as a
/// permission dialog or notification shade.
class AppLockController extends Notifier<bool> with WidgetsBindingObserver {
  /// A background trip shorter than this does not re-lock. Long enough to
  /// absorb an OS dialog, short enough that a real app switch still locks.
  static const _graceWindow = Duration(seconds: 3);

  BiometricService get _service => ref.read(biometricServiceProvider);

  bool _authInProgress = false;
  DateTime? _backgroundedAt;
  bool _observing = false;

  @override
  bool build() {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    }
    // Locked state is resolved asynchronously; start unlocked so the first
    // frame is never blocked, then lock immediately if the preference is on.
    scheduleMicrotask(_lockIfEnabled);
    return false;
  }

  Future<void> _lockIfEnabled() async {
    if (state || _authInProgress) return;
    if (await _service.isEnabled()) state = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Ignore the pause caused by our own prompt.
        if (!_authInProgress) _backgroundedAt = DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (_authInProgress) return;
        if (since == null) return;
        if (DateTime.now().difference(since) < _graceWindow) return;
        scheduleMicrotask(_lockIfEnabled);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Presents the prompt and unlocks on success. Returns the raw outcome so the
  /// lock screen can explain what happened.
  Future<AuthOutcome> unlock() async {
    if (_authInProgress) return AuthOutcome.failed;
    _authInProgress = true;
    try {
      final outcome = await _service.authenticate();
      if (outcome == AuthOutcome.success) state = false;
      return outcome;
    } finally {
      // Cleared after the frame so the resume event caused by the prompt
      // closing is still treated as part of the authentication.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _authInProgress = false;
        _backgroundedAt = null;
      });
    }
  }

  /// Escape hatch for a device that can no longer authenticate — biometrics
  /// unenrolled and no device credential. Turns the preference off so the user
  /// is not permanently shut out of their own data, and records nothing else.
  Future<void> disableAndUnlock() async {
    await _service.setEnabled(false);
    state = false;
  }

  /// Called after sign-out. Clears the *lock*, never the *preference*: the
  /// user's choice must survive logging out and back in.
  void resetForSignOut() {
    _authInProgress = false;
    _backgroundedAt = null;
    state = false;
  }

  /// Re-reads the stored preference — used by the settings screen so the UI can
  /// never drift from what is actually stored.
  Future<bool> isEnabled() => _service.isEnabled();

  /// Turns the lock on or off. Enabling requires a successful authentication
  /// first, so a user cannot lock themselves out with a sensor that does not
  /// actually work.
  Future<AuthOutcome> setEnabled(bool enabled) async {
    if (!enabled) {
      await _service.setEnabled(false);
      state = false;
      return AuthOutcome.success;
    }
    if (_authInProgress) return AuthOutcome.failed;
    _authInProgress = true;
    try {
      final outcome = await _service.authenticate(
        reason: 'Confirm it is you to turn on the app lock',
      );
      if (outcome == AuthOutcome.success) await _service.setEnabled(true);
      return outcome;
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _authInProgress = false;
        _backgroundedAt = null;
      });
    }
  }
}

/// True while the app is locked awaiting authentication.
final appLockedProvider =
    NotifierProvider<AppLockController, bool>(AppLockController.new);
