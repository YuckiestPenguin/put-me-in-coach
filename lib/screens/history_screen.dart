import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloud_sync.dart';
import '../util/format.dart';
import '../widgets/game_summary_sheet.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Past games, newest first. Tap one for its summary; swipe to delete.
class GameHistoryList extends StatelessWidget {
  const GameHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final sync = uid == null ? null : CloudSync(uid);

    if (sync == null) {
      return const Center(child: Text('Sign in to see past games.'));
    }
    return StreamBuilder(
      stream: sync.gamesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text("Couldn't load games."));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final games = snap.data!;
        if (games.isEmpty) {
          return Center(
            child: Text('No games yet. Finished games show up here.',
                style: TextStyle(color: scheme.outline)),
          );
        }
        return ListView.separated(
          itemCount: games.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final g = games[i];
            return Dismissible(
              key: ValueKey(g.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: scheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(Icons.delete, color: scheme.onError),
              ),
              confirmDismiss: (_) => _confirmDelete(context),
              onDismissed: (_) => sync.deleteGame(g.id),
              child: _GameTile(data: g.data),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this game?'),
        content: const Text('This removes it from your history for good.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _GameTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GameTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(data['startedAt'] as String? ?? '');
    final players = (data['players'] as List? ?? []).cast<Map>();
    final present = players.where((p) => p['present'] != false).length;
    final goals =
        players.fold<int>(0, (n, p) => n + ((p['goals'] as int?) ?? 0));
    final title = start == null
        ? 'Game'
        : '${_months[start.month - 1]} ${start.day} · ${clockTime(start)}';
    return ListTile(
      title: Text(title),
      subtitle: Text([
        if (data['teamName'] != null) data['teamName'],
        ?resultText(data),
        mmss(data['gameSeconds'] as int? ?? 0),
        '$present players',
        '$goals goals',
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => GameSummarySheet.showSummary(context, data),
    );
  }
}
