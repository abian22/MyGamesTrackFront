import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_notificationService.initLocalNotifications());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_notificationService.initForUser(uid));
      });
      _tokenRefreshSub = _notificationService.listenTokenRefresh(uid);
      _foregroundSub = _notificationService.listenForegroundMessages();
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    super.dispose();
  }

  Widget _buildPage(int index) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    switch (index) {
      case 0:
        return HomeScreen(uid: uid);
      case 1:
        return FavoritesScreen(uid: uid);
      case 2:
        return NotificationsScreen(uid: uid);
      case 3:
        return ProfileScreen(authService: _authService);
      default:
        return HomeScreen(uid: uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: kBgDark,
      body: _buildPage(_currentIndex),
      bottomNavigationBar: _SwitchNavBar(
        currentIndex: _currentIndex,
        uid: uid,
        onTap: (i) => setState(
          () => _currentIndex = i,
        ), // Al pulsar una pestaña, actualiza el índice y reconstruye el body
      ),
    );
  }
}

class _SwitchNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String uid;

  const _SwitchNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.videogame_asset_rounded, 'Catálogo'),
      (Icons.star_rounded, 'Favoritos'),
      (Icons.notifications_rounded, 'Alertas'),
      (Icons.person_rounded, 'Perfil'),
    ];

    return Container(
      color: kBarDark,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,

          // Genera un botón por cada ítem de la barra
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = currentIndex == i;
              Widget icon = Icon(
                items[i].$1,
                color: selected ? kSwitchRed : Colors.grey[600],
                size: 24,
              );

              if (i == 2) {
                icon = StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('uid', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final count = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return !(data['leida'] == true || data['read'] == true);
                    }).length;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text(
                        '$count',
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: kSwitchRed,
                      child: Icon(
                        items[i].$1,
                        color: selected ? kSwitchRed : Colors.grey[600],
                        size: 24,
                      ),
                    );
                  },
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? kSwitchRed : Colors.grey[600],
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: selected ? 24 : 0,
                        decoration: BoxDecoration(
                          color: kSwitchRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
