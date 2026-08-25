import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push-token lifecycle. Tokens are only registered after the user grants the
/// notification consent toggle AND the OS permission; they are removed on
/// logout so a shared device never receives another user's pushes.
class FcmService {
  FcmService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<bool> requestPermissionAndRegister(String uid) async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return false;
    // Auto-init is disabled in AndroidManifest.xml so no device identifier or
    // network request is created before the user explicitly opts in.
    await _messaging.setAutoInitEnabled(true);
    final token = await _messaging.getToken();
    if (token == null) return false;
    await _firestore.doc('users/$uid/devices/$token').set({
      'platform': 'android',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _messaging.onTokenRefresh.listen((newToken) {
      _firestore.doc('users/$uid/devices/$newToken').set({
        'platform': 'android',
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return true;
  }

  Future<void> unregister(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.doc('users/$uid/devices/$token').delete();
      await _messaging.deleteToken();
    }
    await _messaging.setAutoInitEnabled(false);
  }
}
