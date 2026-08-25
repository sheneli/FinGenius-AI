package com.msc.fingenius

import android.content.pm.ApplicationInfo
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app and exposes a channel to toggle FLAG_SECURE so
 * balance-revealing screens can opt into screenshot/recents protection.
 *
 * FLAG_SECURE is gated on build type rather than switched off wholesale.
 * Release and profile builds get the protection; debug builds do not, so
 * screenshots, screen recording, Appium/UiAutomator2 capture and Firebase
 * Test Lab Robo crawls all keep working against a debug APK. Removing the
 * flag entirely would have made the control's absence a permanent property
 * of the shipped app in order to solve a temporary tooling problem.
 *
 * The gate reads ApplicationInfo.FLAG_DEBUGGABLE rather than BuildConfig.DEBUG:
 * AGP 8 no longer generates BuildConfig unless `buildFeatures.buildConfig` is
 * enabled, and this module does not enable it. FLAG_DEBUGGABLE is set from the
 * build type, not the signing config, so it still reports false for a release
 * build even though this project signs release with the debug keystore for
 * assessment demos (see android/app/build.gradle.kts).
 *
 * Extends [FlutterFragmentActivity], not `FlutterActivity`: AndroidX
 * BiometricPrompt — which `local_auth` uses for the app lock — must be hosted
 * by a FragmentActivity. With a plain FlutterActivity every authenticate()
 * call fails with `no_fragment_activity` and the prompt never appears, which
 * is why the biometric lock silently did nothing on real devices.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "fingenius/secure_screen"

    /** True for debug builds, where capture tooling must be able to see the screen. */
    private val isDebuggableBuild: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        if (isDebuggableBuild) {
                            // Debug build: leave the window capturable and tell
                            // Dart the flag was not applied, so the UI can
                            // surface the weakened state if it ever needs to.
                            result.success(false)
                        } else {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE,
                            )
                            result.success(true)
                        }
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
