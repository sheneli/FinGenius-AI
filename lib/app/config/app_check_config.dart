/// Whether to install Firebase App Check.
///
/// **Off by default, and that is deliberate.**
///
/// Activating App Check installs a token provider that the Auth, Firestore and
/// Storage SDKs *await before every request*. When the app is registered and
/// attestation succeeds that wait is milliseconds. When the app is **not**
/// registered in the Firebase console, Play Integrity can never mint a token:
/// the SDK retries with exponential backoff on each call before finally
/// proceeding without one. The visible symptom is a sign-in button that spins
/// for minutes on a real device — a release build hits this hardest, because
/// release uses Play Integrity while debug uses the far more forgiving debug
/// provider.
///
/// Leaving it off costs nothing today: App Check only protects a backend once
/// **enforcement** is switched on per-API in the console, and enforcement
/// cannot be switched on for an unregistered app. So while the console shows
/// FinGenius as "Unregistered", activation buys zero protection and imposes the
/// full latency penalty.
///
/// ## Turning it on (in this order — the order matters)
///
/// 1. Register the app in Firebase console → App Check → Play Integrity, using
///    the SHA-256 fingerprint of the signing key you actually ship.
/// 2. Rebuild with the flag on:
///    `flutter build apk --release --dart-define=APP_CHECK_ENABLED=true`
/// 3. Confirm real requests are succeeding and tokens are being minted.
/// 4. Only then enable enforcement per API.
///
/// Enabling enforcement before step 3 rejects every request from the app.
abstract final class AppCheckConfig {
  static const enabled =
      bool.fromEnvironment('APP_CHECK_ENABLED', defaultValue: false);
}
