import 'package:flutter/services.dart';
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
      BuildContext context, GameState state, int id) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => Consumer<GameState>(
        builder: (context, state, _) {
          final p = state.roster.firstWhere((p) => p.id == id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.displayName,
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Edit name / number',
                        onPressed: () => _showRenameDialog(context, state, p),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      p.isPresent ? Icons.check_circle : Icons.cancel,
                      color: p.isPresent
                          ? Colors.green
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: const Text('Here today',
                        style: TextStyle(fontSize: 17)),
                    subtitle: p.isPresent
                        ? null
                        : const Text('Grayed out and can\'t be put in'),
                    value: p.isPresent,
                    onChanged: (v) {
                      Alerts.tap();
                      state.setPresent(p.id, v);
                    },
                  ),
                  const Divider(height: 8),
                  _RoleTile(
                    leading: const Text('🧤', style: TextStyle(fontSize: 24)),
                    title: 'Goalie',
                    value: p.isGoalie,
                    onChanged: () {
                      Alerts.tap();
                      state.toggleRole(p.id, PlayerRole.goalie);
                    },
                  ),
                  _RoleTile(
                    leading: const Icon(Icons.star,
                        color: Color(0xFFFFC107), size: 26),
                    title: 'Favorite',
                    value: p.isFavorite,
                    onChanged: () {
                      Alerts.tap();
                      state.toggleRole(p.id, PlayerRole.favorite);
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
                      state.toggleRole(p.id, PlayerRole.captain);
                    },
                  ),
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmRemove(context, state, p),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        icon: const Icon(Icons.person_remove),
                        label: const Text('Remove from game (injured / left)'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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

  static void _showRenameDialog(
      BuildContext context, GameState state, Player p) {
    final nameController = TextEditingController(text: p.name);
    final numberController =
        TextEditingController(text: p.number?.toString() ?? '');
    void save(BuildContext dialogCtx) {
      if (nameController.text.trim().isEmpty) return;
      state.editPlayer(
          p.id, nameController.text, int.tryParse(numberController.text.trim()));
      Navigator.pop(dialogCtx);
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number (optional)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => save(dialogCtx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => save(dialogCtx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void _confirmRemove(BuildContext context, GameState state, Player p) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Remove ${p.displayName}?'),
        content: const Text(
            'Use this if a player is injured or leaves the game early. '
            'This removes them from the roster and playing-time tracking '
            'for the rest of the game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              state.removePlayer(p.id);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
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
