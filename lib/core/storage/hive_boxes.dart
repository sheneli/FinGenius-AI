import 'package:hive_ce_flutter/hive_flutter.dart';

/// Per-user Hive boxes. Box names embed the uid so local data is isolated
/// between accounts on a shared device; [clearUser] wipes them on logout.
class HiveBoxes {
  HiveBoxes._();

  static Future<void> init() => Hive.initFlutter();

  static String _cacheName(String uid) => 'cache_$uid';
  static String _queueName(String uid) => 'queue_$uid';
  static String _metaName(String uid) => 'meta_$uid';

  static Future<Box<Map<dynamic, dynamic>>> cache(String uid) =>
      Hive.openBox<Map<dynamic, dynamic>>(_cacheName(uid));
  static Future<Box<Map<dynamic, dynamic>>> queue(String uid) =>
      Hive.openBox<Map<dynamic, dynamic>>(_queueName(uid));

  /// meta: lastSyncedAt timestamps, draft forms, learned categoriser map.
  static Future<Box<dynamic>> meta(String uid) => Hive.openBox<dynamic>(_metaName(uid));

  /// Deletes every box belonging to [uid] — called on logout/account deletion.
  static Future<void> clearUser(String uid) async {
    for (final name in [_cacheName(uid), _queueName(uid), _metaName(uid)]) {
      if (Hive.isBoxOpen(name)) await Hive.box<dynamic>(name).close();
      await Hive.deleteBoxFromDisk(name);
    }
  }
}
