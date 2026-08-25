import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/session_providers.dart';
import 'connectivity_provider.dart';

/// What the app can currently do with the user's data.
enum SyncState {
  /// Reads and writes are reaching the server.
  synced,

  /// The device has no network. Writes queue locally and will sync later.
  deviceOffline,

  /// The device *has* a network but the backend is not answering. Writes still
  /// queue locally, but nothing is reaching the cloud and the user needs to
  /// know that — silently pretending to sync is how data quietly goes missing.
  backendUnreachable,
}

/// Distinguishes "no signal" from "signal, but the server isn't answering".
///
/// The offline banner used to be driven purely by `connectivity_plus`, which
/// reports whether a *radio* is up — not whether anything is reachable. On a
/// phone with full WiFi but an unreachable Firestore backend the banner stayed
/// hidden while every write silently piled up in the local queue. That is the
/// worst of both worlds: the user believes their data is saved to the cloud.
///
/// Firestore itself is the reliable signal. Every snapshot carries
/// `metadata.isFromCache`, which is true while the SDK is serving from its
/// local cache because it cannot reach the server. This watches the user
/// document — already streamed elsewhere, so no meaningful extra cost — and
/// only reports trouble once the cache-only condition has persisted, so a
/// normal cold start does not flash a scary banner before the first server
/// snapshot arrives.
class SyncStatusNotifier extends Notifier<SyncState> {
  /// How long the client may serve from cache before we call it unreachable.
  /// Comfortably longer than a cold start on a slow connection.
  static const _grace = Duration(seconds: 12);

  StreamSubscription<bool>? _sub;
  Timer? _ticker;
  DateTime? _cacheOnlySince;

  @override
  SyncState build() {
    final uid = ref.watch(currentUidProvider);
    ref.onDispose(() {
      _sub?.cancel();
      _ticker?.cancel();
    });

    if (uid == null) {
      // Nothing to sync while signed out.
      return SyncState.synced;
    }

    _sub = ref
        .watch(firestoreProvider)
        .doc('users/$uid')
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.metadata.isFromCache)
        .listen(_onCacheFlag, onError: (_) => _onCacheFlag(true));

    // Re-evaluates while nothing new arrives — an unreachable backend produces
    // no snapshots at all, so the state must be driven by elapsed time too.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _evaluate());
    _cacheOnlySince = DateTime.now();

    return SyncState.synced;
  }

  void _onCacheFlag(bool isFromCache) {
    _cacheOnlySince = isFromCache ? (_cacheOnlySince ?? DateTime.now()) : null;
    _evaluate();
  }

  void _evaluate() {
    if (!ref.read(isOnlineProvider)) {
      state = SyncState.deviceOffline;
      return;
    }
    final since = _cacheOnlySince;
    if (since != null && DateTime.now().difference(since) >= _grace) {
      state = SyncState.backendUnreachable;
      return;
    }
    if (since == null) state = SyncState.synced;
  }
}

final syncStateProvider =
    NotifierProvider<SyncStatusNotifier, SyncState>(SyncStatusNotifier.new);

/// Banner copy for a given state, or null when there is nothing to say.
String? syncBannerMessage(SyncState state) => switch (state) {
      SyncState.synced => null,
      SyncState.deviceOffline =>
        'Offline — changes are saved here and will sync when you reconnect',
      SyncState.backendUnreachable =>
        "Can't reach the server — changes are saved on this device only",
    };
