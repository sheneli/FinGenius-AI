import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/dates.dart';

/// Local notifications for bill reminders and behaviour nudges.
/// Quiet hours are enforced here: anything scheduled inside the user's quiet
/// window is deferred to the window's end.
class LocalNotificationsService {
  LocalNotificationsService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'fingenius_reminders',
    'Reminders & nudges',
    channelDescription: 'Bill reminders, budget alerts and financial nudges',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_fingenius',
  );

  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_fingenius'),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Shows immediately unless inside quiet hours, in which case it is dropped
  /// (caller may reschedule). Persistent in-app copies live in Firestore.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required int quietStartMin,
    required int quietEndMin,
  }) async {
    await init();
    final now = DateTime.now();
    if (Dates.inQuietHours(now.hour * 60 + now.minute, quietStartMin, quietEndMin)) return;
    await _plugin.show(id, title, body, const NotificationDetails(android: _channel));
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

final localNotificationsProvider =
    Provider<LocalNotificationsService>((_) => LocalNotificationsService());
