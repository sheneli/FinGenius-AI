import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// Outcome of one authentication attempt.
///
/// The previous implementation collapsed every failure into `false`, which made
/// four very different situations indistinguishable: the user pressing cancel,
/// too many wrong fingers, biometrics never enrolled, and the plugin being
/// unable to run at all. They need different messages and different recovery,
/// so each is now its own case.
enum AuthOutcome {
  success,

  /// Wrong finger/face, or the sensor could not read. Retrying is reasonable.
  failed,

  /// User dismissed the prompt. Not an error — say nothing accusatory.
  canceled,

  /// No biometric hardware, or the platform cannot present a prompt.
  unavailable,

  /// Hardware exists but nothing is enrolled, and no device credential is set.
  notEnrolled,

  /// Too many attempts; Android will allow retries after a cool-down.
  lockedOut,

  /// Locked until the user unlocks the device by other means.
  permanentlyLockedOut,
}

/// Whether the app lock can be offered at all, and why not when it can't.
enum LockAvailability {
  /// Biometrics or a device credential can authenticate the user.
  available,

  /// Hardware present but nothing enrolled and no PIN/pattern/password set.
  notEnrolled,

  /// Device cannot do this.
  unsupported,
}

/// Opt-in biometric app lock. The preference lives in Android secure storage;
/// authentication uses BiometricPrompt with device-credential fallback.
class BiometricService {
  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;
  static const _key = 'biometric_lock_enabled';

  /// Reports *why* the lock is unavailable, so the settings screen can explain
  /// itself instead of just greying the switch out.
  Future<LockAvailability> availability() async {
    try {
      if (!await _auth.isDeviceSupported()) return LockAvailability.unsupported;
      // isDeviceSupported() is true when a device credential exists even with
      // no biometric enrolled — and a PIN alone is a perfectly good app lock,
      // so that counts as available.
      if (await _auth.canCheckBiometrics) return LockAvailability.available;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? LockAvailability.available // device credential only
          : LockAvailability.available;
    } on PlatformException catch (e) {
      developer.log('availability check failed: ${e.code}', name: 'AppLock');
      return LockAvailability.unsupported;
    }
  }

  /// Kept for callers that only need a yes/no.
  Future<bool> isSupported() async =>
      (await availability()) == LockAvailability.available;

  Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _key)) == 'true';
    } catch (e) {
      // A corrupt keystore entry must not brick startup; treat it as "off".
      developer.log('could not read lock preference: $e', name: 'AppLock');
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _key, value: enabled.toString());

  /// Presents the system prompt. `biometricOnly: false` keeps the device
  /// PIN/pattern/password available as a fallback, which is what stops a user
  /// whose fingerprint stops working from being shut out of their own data.
  Future<AuthOutcome> authenticate({
    String reason = 'Unlock FinGenius AI',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return ok ? AuthOutcome.success : AuthOutcome.canceled;
    } on PlatformException catch (e) {
      final outcome = _mapError(e.code);
      // Code only — an auth error message can name the enrolled user.
      developer.log('authenticate failed: ${e.code} → $outcome',
          name: 'AppLock');
      return outcome;
    } catch (e) {
      developer.log('authenticate error: ${e.runtimeType}', name: 'AppLock');
      return AuthOutcome.unavailable;
    }
  }

  static AuthOutcome _mapError(String code) => switch (code) {
        auth_error.notAvailable => AuthOutcome.unavailable,
        auth_error.notEnrolled => AuthOutcome.notEnrolled,
        auth_error.passcodeNotSet => AuthOutcome.notEnrolled,
        auth_error.lockedOut => AuthOutcome.lockedOut,
        auth_error.permanentlyLockedOut => AuthOutcome.permanentlyLockedOut,
        // Thrown when the host activity is not a FragmentActivity. If this ever
        // reappears, MainActivity has regressed to FlutterActivity.
        'no_fragment_activity' => AuthOutcome.unavailable,
        _ => AuthOutcome.failed,
      };

  Future<void> clear() => _storage.delete(key: _key);
}

final biometricServiceProvider = Provider<BiometricService>((_) => BiometricService());
