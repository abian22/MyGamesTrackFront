import 'package:flutter/material.dart';
import '../constants.dart';

class GameCard extends StatelessWidget {
  final String gameId;
  final Map<String, dynamic> game;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const GameCard({
    super.key,
    required this.gameId,
    required this.game,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final title     = game['titulo']    ?? 'Sin título';
    final imageUrl  = game['imagen']    as String?;
    final precio    = _formatPrice(game['precio']);
    final descuento = game['descuento'] ?? '';
    final genre     = game['genero']    ?? '';

    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(title),
                      )
                    : _placeholder(title),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: isFavorite ? Colors.amber : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (genre.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    genre,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  descuento.isNotEmpty && precio != 'Precio no disponible'
                      ? '$precio ($descuento)'
                      : precio,
                  style: TextStyle(
                    color: precio == 'Precio no disponible'
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title) {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return 'Precio no disponible';
    if (rawPrice is num) return '${rawPrice.toStringAsFixed(2)} EUR';
    final text = rawPrice.toString().trim();
    if (text.isEmpty) return 'Precio no disponible';
    return text;
  }
}