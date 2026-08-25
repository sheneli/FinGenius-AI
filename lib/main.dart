import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'app/config/app_check_config.dart';
import 'core/analytics/analytics_service.dart';
import 'core/diagnostics/boot_trace.dart';
import 'core/storage/hive_boxes.dart';

/// Startup is split in two: the short list of things the first frame genuinely
/// cannot render without, and everything else.
///
/// Only Firebase core and Hive are on the critical path — both are local. App
/// Check, Crashlytics collection and the Remote Config fetch each require a
/// network round-trip, and awaiting them before `runApp` meant the user stared
/// at a blank window until every one of them finished or timed out. On a slow
/// or captive connection that is the entire perceived load time of the login
/// screen. They now start after the first frame and settle in the background.
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    BootTrace.mark('binding');

    // The typeface is bundled (assets/google_fonts). Refusing runtime fetching
    // makes that guarantee explicit: no cold start can block on a font
    // download, and a missing asset fails loudly in debug instead of silently
    // costing seconds on every launch.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Android-only: options come from android/app/google-services.json via the
    // Google Services Gradle plugin (docs/assumptions.md A-02).
    await BootTrace.step('firebaseCore', Firebase.initializeApp);

    // Handlers are wired immediately — they cost nothing and must be in place
    // before any of the background initialisation below can fail.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await BootTrace.step('hive', HiveBoxes.init);

    runApp(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(
              AnalyticsService(FirebaseAnalytics.instance)),
        ],
        child: const FinGeniusApp(),
      ),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => BootTrace.reportFirstFrame());

    unawaited(_initOffCriticalPath());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

/// Network-dependent setup that no screen waits on.
///
/// Every step is individually guarded: a failure here must never take the app
/// down, because the app is already on screen and usable by the time this runs.
/// Remote Config is not touched at all — [remoteConfigProvider] fetches it
/// lazily on first read and falls back to the local defaults until it lands.
Future<void> _initOffCriticalPath() async {
  // App Check: Play Integrity in release; debug provider for development.
  // Gated because activating it makes every Auth/Firestore request wait on a
  // token this app cannot yet mint — see AppCheckConfig for the full reasoning
  // and the order to turn it on in.
  if (AppCheckConfig.enabled) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      );
    } catch (e) {
      debugPrint('App Check unavailable: $e');
    }
  } else {
    debugPrint('App Check not activated (APP_CHECK_ENABLED=false)');
  }
  BootTrace.mark('appCheck(bg)');

  try {
    // Crashlytics: framework + async errors. Disabled in debug builds.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(kReleaseMode);
  } catch (e) {
    debugPrint('Crashlytics toggle failed: $e');
  }
  BootTrace.mark('crashlytics(bg)');
}
