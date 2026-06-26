import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../services/alerts.dart';

/// Bottom sheet to set a player's role markers (goalie / captain / favorite).
/// Each role is single-assignment, so turning one on moves it off whoever had
/// it before.
class PlayerRoleSheet {
  static Future<void> show(
      BuildContext context, GameState state, int number) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => Consumer<GameState>(
        builder: (context, state, _) {
          final p = state.roster.firstWhere((p) => p.number == number);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Player ${p.number}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  _RoleTile(
                    leading: const Text('🧤', style: TextStyle(fontSize: 24)),
                    title: 'Goalie',
                    value: p.isGoalie,
                    onChanged: () {
                      Alerts.tap();
                      state.toggleRole(p.number, PlayerRole.goalie);
                    },
                  ),
                  _RoleTile(
                    leading: const Icon(Icons.star,
                        color: Color(0xFFFFC107), size: 26),
                    title: 'Favorite',
                    value: p.isFavorite,
                    onChanged: () {
                      Alerts.tap();
                      state.toggleRole(p.number, PlayerRole.favorite);
                    },
                  ),
                  _RoleTile(
                    leading: const CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFF1565C0),
                      child: Text('C',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    title: 'Captain',
                    value: p.isCaptain,
                    onChanged: () {
                      Alerts.tap();
                      state.toggleRole(p.number, PlayerRole.captain);
                    },
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final bool value;
  final VoidCallback onChanged;

  const _RoleTile({
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: leading,
      title: Text(title, style: const TextStyle(fontSize: 17)),
      value: value,
      onChanged: (_) => onChanged(),
    );
  }
}
