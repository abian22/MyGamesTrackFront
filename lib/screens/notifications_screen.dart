import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

class NotificationsScreen extends StatelessWidget {
  final String uid;
  const NotificationsScreen({super.key, required this.uid});

  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
  }

  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).update({
      'leida': true,
      'read': true,
    });
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final alreadyRead = data['leida'] == true || data['read'] == true;
      if (alreadyRead) continue;
      batch.update(doc.reference, {'leida': true, 'read': true});
    }
    await batch.commit();
  }

  String _buildMessage(Map<String, dynamic> data) {
    final title = (data['gameTitle'] ?? data['titulo'] ?? 'Juego').toString();
    final oldPrice = data['oldPrice'];
    final newPrice = data['newPrice'];
    if (oldPrice != null && newPrice != null) {
      return '$title bajó de ${oldPrice.toString()} a ${newPrice.toString()}';
    }
    return (data['message'] ?? 'Cambio de precio detectado en tus favoritos').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        title: Row(
          children: const [
            _Dot(color: kSwitchRed),
            SizedBox(width: 6),
            _Dot(color: kSwitchBlue),
            SizedBox(width: 10),
            Text(
              'Alertas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(docs),
                child: const Text(
                  'Marcar todas',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error cargando alertas: ${snapshot.error}',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kSwitchRed),
            );
          }

          final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tsA = dataA['createdAt'];
            final tsB = dataB['createdAt'];
            final dateA = tsA is Timestamp ? tsA.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = tsB is Timestamp ? tsB.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No tienes alertas todavía',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, index) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final read = data['leida'] == true || data['read'] == true;
              final ts = data['createdAt'];
              final date = ts is Timestamp ? ts.toDate() : null;
              final imageUrl = (data['gameImage'] ?? data['imagen'] ?? '').toString();

              return ListTile(
                onTap: () => _markAsRead(doc.id),
                tileColor: read ? Colors.transparent : Colors.white10,
                leading: _GameImageThumb(imageUrl: imageUrl, read: read),
                title: Text(
                  _buildMessage(data),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  date == null
                      ? 'Ahora'
                      : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!read) const Icon(Icons.circle, color: kSwitchRed, size: 10),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      tooltip: 'Eliminar notificación',
                      onPressed: () => _deleteNotification(doc.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GameImageThumb extends StatelessWidget {
  final String imageUrl;
  final bool read;
  const _GameImageThumb({required this.imageUrl, required this.read});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => _fallback(read),
        ),
      );
    }
    return _fallback(read);
  }

  Widget _fallback(bool read) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        read ? Icons.notifications_none : Icons.notifications_active,
        color: read ? Colors.white54 : kSwitchRed,
        size: 20,
      ),
    );
  }
}
