import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Phase timings for app startup.
///
/// Startup complaints are otherwise unfalsifiable — "the login page is slow"
/// gives no way to tell a slow network from a slow disk from a slow build. Each
/// phase is stamped as it completes and the whole sequence is printed once, so a
/// bad launch can be attributed from a single log line.
///
/// Cheap enough to leave in release: a handful of ints and one log line.
abstract final class BootTrace {
  static final Stopwatch _watch = Stopwatch()..start();
  static final List<(String, int)> _marks = [];
  static bool _reported = false;

  /// Milliseconds since the Dart entrypoint began.
  static int get elapsedMs => _watch.elapsedMilliseconds;

  /// Records that [phase] has just finished.
  static void mark(String phase) {
    _marks.add((phase, _watch.elapsedMilliseconds));
    // Shows up on the Performance timeline alongside frame data.
    developer.Timeline.instantSync('boot.$phase');
  }

  /// Logs the sequence once the first frame is on screen.
  static void reportFirstFrame() {
    if (_reported) return;
    _reported = true;
    mark('firstFrame');
    var previous = 0;
    final parts = <String>[];
    for (final (phase, at) in _marks) {
      parts.add('$phase=${at - previous}ms');
      previous = at;
    }
    debugPrint('BOOT total=${_marks.last.$2}ms  ${parts.join('  ')}');
  }

  /// Times a single asynchronous startup step and marks it.
  static Future<T> step<T>(String phase, Future<T> Function() body) async {
    try {
      return await body();
    } finally {
      mark(phase);
    }
  }
}
