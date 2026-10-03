import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../util/format.dart';

/// Simple end-of-game recap: start/end time, then who played, for how long,
/// and goals scored.
class GameSummarySheet extends StatelessWidget {
  final GameState state;
  const GameSummarySheet({super.key, required this.state});

  static Future<void> show(BuildContext context, GameState state) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GameSummarySheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final players = state.roster.where((p) => p.isPresent).toList()
      ..sort((a, b) => b.secondsPlayed.compareTo(a.secondsPlayed));
    final absent = state.roster.where((p) => !p.isPresent).toList();
    final goals = players.fold<int>(0, (n, p) => n + p.goals);
    final start = state.startedAt;
    final end = state.endedAt;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Game summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              [
                if (start != null) 'Started ${clockTime(start)}',
                if (end != null) 'Ended ${clockTime(end)}',
                'Game clock ${mmss(state.gameSeconds)}',
              ].join(' · '),
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    1: IntrinsicColumnWidth(),
                    2: IntrinsicColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _row(context, 'Player', 'Played', 'Goals', header: true),
                    for (final p in players)
                      _row(
                        context,
                        p.number == null
                            ? p.displayName
                            : '${p.number} · ${p.displayName}',
                        mmss(p.secondsPlayed),
                        p.goals == 0 ? '–' : '${p.goals}',
                      ),
                    _row(context, 'Total goals', '', '$goals', header: true),
                  ],
                ),
              ),
            ),
            if (absent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Absent: ${absent.map((p) => p.displayName).join(', ')}',
                style: TextStyle(color: scheme.outline, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _row(BuildContext context, String a, String b, String c,
      {bool header = false}) {
    final style = TextStyle(
      fontSize: 16,
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
    );
    Widget cell(String t, {bool right = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: Text(t,
              style: style, textAlign: right ? TextAlign.right : null),
        );
    return TableRow(
      decoration: header
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest)
          : null,
      children: [cell(a), cell(b, right: true), cell(c, right: true)],
    );
  }
}
