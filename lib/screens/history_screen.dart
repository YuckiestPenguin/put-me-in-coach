import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloud_sync.dart';
import '../util/format.dart';
import '../widgets/game_summary_sheet.dart';
import '../widgets/slow_load_notice.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Past games, newest first. Tap one for its summary; swipe to delete.
class GameHistoryList extends StatefulWidget {
  const GameHistoryList({super.key});

  @override
  State<GameHistoryList> createState() => _GameHistoryListState();
}

class _GameHistoryListState extends State<GameHistoryList> {
  CloudSync? _sync;
  Stream<List<({String id, Map<String, dynamic> data, bool pending})>>? _games;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _sync = CloudSync(uid);
      _games = _sync!.gamesStream();
    }
  }

  /// Re-subscribe, e.g. after a stalled connection.
  void _retry() => setState(() => _games = _sync!.gamesStream());

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sync = _sync;
    if (sync == null || _games == null) {
      return const Center(child: Text('Sign in to see past games.'));
    }
    return StreamBuilder(
      stream: _games,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Couldn't load games."),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.outline, fontSize: 12)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return SlowLoadNotice(onRetry: _retry, diagnose: sync.probe);
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
              child: _GameTile(data: g.data, pending: g.pending),
            );
          },
        );
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool pending;
  const _GameTile({required this.data, required this.pending});

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
      trailing: pending
          ? Tooltip(
              message: 'Not synced yet',
              child: Icon(Icons.cloud_off,
                  size: 20, color: Theme.of(context).colorScheme.outline),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => GameSummarySheet.showSummary(context, data),
    );
  }
}
