import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../widgets/game_card.dart';
import '../widgets/switch_app_bar.dart';

class FavoritesScreen extends StatelessWidget {
  final String uid;
  const FavoritesScreen({super.key, required this.uid});

  Future<void> _removeFavorite(String gameId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc  = await userRef.get();
    final data = doc.data();
    if (data == null) return;
    final favs = Set<String>.from(data['favorites'] ?? []);
    favs.remove(gameId);
    await userRef.update({'favorites': favs.toList()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: const SwitchAppBar(title: 'Favoritos'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kSwitchRed));
          }

          final data        = userSnap.data?.data() as Map<String, dynamic>?;
          final favoriteIds = Set<String>.from(data?['favorites'] ?? []);

          if (favoriteIds.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border_rounded, color: Colors.white24, size: 64),
                  SizedBox(height: 12),
                  Text('No tienes favoritos aún', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Pulsa la estrella en cualquier juego', style: TextStyle(color: Colors.white30, fontSize: 13)),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('games')
                .where(FieldPath.documentId, whereIn: favoriteIds.toList())
                .snapshots(),
            builder: (context, gamesSnap) {
              if (gamesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kSwitchRed));
              }

              final docs = gamesSnap.data?.docs ?? [];

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc  = docs[i];
                  final game = doc.data() as Map<String, dynamic>;
                  return GameCard(
                    gameId: doc.id,
                    game: game,
                    isFavorite: true,
                    onToggleFavorite: () => _removeFavorite(doc.id),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}