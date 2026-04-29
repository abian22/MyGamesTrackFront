import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, debugPrint, TargetPlatform;

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
