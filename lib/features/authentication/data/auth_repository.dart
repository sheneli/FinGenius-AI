import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Wraps FirebaseAuth with typed failures and user-friendly messages.
/// No sensitive values are ever logged.
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  /// Ceiling on a single authentication round-trip.
  ///
  /// Firebase Auth answers in well under a second on a healthy connection, and
  /// it has no client-side deadline of its own — it retries internally for as
  /// long as it takes. Without this bound, a stalled request showed the user an
  /// indefinite spinner with no way out and no explanation. This is a safety
  /// net, not the cure: the stall it was masking is fixed in [AppCheckConfig].
  static const _authTimeout = Duration(seconds: 30);

  /// Times an authentication step so a slow sign-in can be attributed from a
  /// single log line rather than guessed at.
  Future<T> _timed<T>(String step, Future<T> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      return await body();
    } finally {
      // debugPrint, not developer.log: dart:developer output goes to the VM
      // service and never reaches logcat in a release build, which is exactly
      // where this timing is needed.
      debugPrint('AUTH $step took ${watch.elapsedMilliseconds}ms');
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<Result<User>> signUp({required String email, required String password, required String displayName}) =>
      _run(() async {
        final cred = await _timed(
          'createUserWithEmailAndPassword',
          () => _auth
              .createUserWithEmailAndPassword(
                  email: email.trim(), password: password)
              .timeout(_authTimeout),
        );
        await cred.user!.updateDisplayName(displayName.trim()).timeout(_authTimeout);
        // Non-fatal: the account exists, and verification can be re-sent from
        // the verify-email screen. Failing the whole sign-up here would leave
        // the user with an account they were told was not created.
        try {
          await cred.user!.sendEmailVerification().timeout(_authTimeout);
        } catch (e) {
          debugPrint('AUTH verification email deferred: ${e.runtimeType}');
        }
        return cred.user!;
      });

  Future<Result<User>> signIn({required String email, required String password}) =>
      _run(() async {
        try {
          final cred = await _timed(
            'signInWithEmailAndPassword',
            () => _auth
                .signInWithEmailAndPassword(
                    email: email.trim(), password: password)
                .timeout(_authTimeout),
          );
          return cred.user!;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') {
            // Check if user exists or create if needed
            try {
              final newCred = await _timed(
                'createUserWithEmailAndPassword',
                () => _auth
                    .createUserWithEmailAndPassword(
                        email: email.trim(), password: password)
                    .timeout(_authTimeout),
              );
              return newCred.user!;
            } catch (_) {
              rethrow;
            }
          }
          rethrow;
        }
      });

  Future<Result<void>> sendPasswordReset(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<Result<void>> resendVerification() => _run(() async {
        await _auth.currentUser?.sendEmailVerification();
      });

  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Required before destructive actions (account deletion).
  Future<Result<void>> reauthenticate(String password) => _run(() async {
        final user = _auth.currentUser;
        if (user?.email == null) throw FirebaseAuthException(code: 'no-user');
        await user!.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      });

  Future<Result<void>> deleteAccount() => _run(() async {
        await _auth.currentUser?.delete();
      });

  Future<void> signOut() => _auth.signOut();

  Future<Result<T>> _run<T>(Future<T> Function() body) => guard(
        body,
        onError: (e, _) => switch (e) {
          FirebaseAuthException() =>
            AuthFailure(_message(e.code), code: e.code, cause: e),
          TimeoutException() => const AuthFailure(
              'Could not reach the sign-in service. Check your connection and '
              'try again.',
              code: 'timeout',
            ),
          _ => UnknownFailure('Something went wrong. Please try again.',
              cause: e),
        },
      );

  static String _message(String code) => switch (code) {
        'email-already-in-use' => 'An account already exists for this email. Try signing in.',
        'invalid-email' => 'That email address looks invalid.',
        'weak-password' => 'That password is too weak — use at least 8 characters with a number.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
        'network-request-failed' => 'No connection. Check your network and try again.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled in the Firebase console yet '
              '(Authentication → Sign-in method). See docs/setup/firebase_setup.md.',
        'requires-recent-login' => 'Please confirm your password to continue.',
        _ => 'Authentication failed. Please try again.',
      };
}
