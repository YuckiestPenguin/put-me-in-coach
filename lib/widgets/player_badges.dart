import 'package:flutter/material.dart';

import '../models/player.dart';

/// Small role markers shown next to a player's number:
/// C captain, 🧤 goalie, ⭐ favorite. Renders nothing if the player has none.
class PlayerBadges extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerBadges({super.key, required this.player, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final markers = <Widget>[
      if (player.isCaptain) _CaptainBadge(size: size),
      if (player.isGoalie)
        Text('🧤', style: TextStyle(fontSize: size)),
      if (player.isFavorite)
        Icon(Icons.star, color: const Color(0xFFFFC107), size: size + 2),
    ];
    if (markers.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: markers,
    );
  }
}

class _CaptainBadge extends StatelessWidget {
  final double size;
  const _CaptainBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1565C0),
        shape: BoxShape.circle,
      ),
      child: Text(
        'C',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.66,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
