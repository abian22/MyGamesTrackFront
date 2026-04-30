import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, debugPrint, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initLocalNotifications() async {
    if (kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings);
  }

  Future<void> initForUser(String uid) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _messaging
            .requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(const Duration(seconds: 8));
      }

      final token = await _messaging
          .getToken()
          .timeout(const Duration(seconds: 8));
      if (token != null) {
        await _saveToken(uid, token);
      }
    } on TimeoutException {
      debugPrint('Timeout inicializando notificaciones');
    } catch (e) {
      debugPrint('Error inicializando notificaciones: $e');
    }
  }

  StreamSubscription<String> listenTokenRefresh(String uid) {
    return _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(uid, token);
    });
  }

  StreamSubscription<RemoteMessage> listenForegroundMessages() {
    return FirebaseMessaging.onMessage.listen((message) async {
      if (kIsWeb) return;
      final title = message.notification?.title ?? 'Nueva alerta';
      final body = message.notification?.body ?? 'Tienes una nueva notificacion';

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'price_alerts_channel',
            'Price Alerts',
            channelDescription: 'Notificaciones de bajadas de precio',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
