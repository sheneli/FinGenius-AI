import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Toggles Android FLAG_SECURE via MethodChannel (see MainActivity.kt).
/// Wrap balance-revealing screens with [SecureScreen] to block screenshots
/// and hide content in the recents switcher.
///
/// The platform side gates the flag on build type: release and profile builds
/// apply it, debug builds do not, so screenshot and screen-recording capture
/// keeps working during development, automated UI testing and demonstration
/// without the control being absent from the shipped app.
class SecureScreenChannel {
  static const _channel = MethodChannel('fingenius/secure_screen');

  /// Requests screenshot protection for the current window.
  ///
  /// Returns true when FLAG_SECURE was actually applied. A debug build returns
  /// false — the request succeeded, the flag was deliberately not set.
  static Future<bool> enable() async {
    try {
      return await _channel.invokeMethod<bool>('enable') ?? false;
    } on PlatformException {
      // Non-fatal: continue without the flag (e.g. in tests).
      return false;
    } on MissingPluginException {
      // No platform side (widget tests, non-Android hosts).
      return false;
    }
  }

  /// Clears screenshot protection for the current window.
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<bool>('disable');
    } on PlatformException {
      // Non-fatal.
    } on MissingPluginException {
      // No platform side.
    }
  }
}

class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});
  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecureScreenChannel.enable();
  }

  @override
  void dispose() {
    SecureScreenChannel.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
