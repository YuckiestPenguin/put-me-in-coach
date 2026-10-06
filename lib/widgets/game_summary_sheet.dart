import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../util/format.dart';

/// Simple game recap: start/end time, then who played, for how long, and goals
/// scored. Works from a summary map ([GameState.summaryJson] format) so it can
/// show the game just finished or one loaded from history.
class GameSummarySheet extends StatelessWidget {
  final Map<String, dynamic> summary;
  const GameSummarySheet({super.key, required this.summary});

  /// Summary of the game in progress / just ended.
  static Future<void> show(BuildContext context, GameState state) =>
      showSummary(context, state.summaryJson());

  static Future<void> showSummary(
      BuildContext context, Map<String, dynamic> summary) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GameSummarySheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = [
      for (final p in (summary['players'] as List? ?? []))
        Map<String, dynamic>.from(p as Map)
    ];
    final players = all.where((p) => p['present'] != false).toList()
      ..sort((a, b) => (b['secondsPlayed'] as int? ?? 0)
          .compareTo(a['secondsPlayed'] as int? ?? 0));
    final absent = all.where((p) => p['present'] == false).toList();
    final goals = players.fold<int>(0, (n, p) => n + (p['goals'] as int? ?? 0));
    final start = DateTime.tryParse(summary['startedAt'] as String? ?? '');
    final end = DateTime.tryParse(summary['endedAt'] as String? ?? '');

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
            if (summary['teamName'] != null || summary['leagueName'] != null)
              Text(
                [
                  if (summary['teamName'] != null) summary['teamName'],
                  if (summary['leagueName'] != null) summary['leagueName'],
                ].join(' · '),
                style: const TextStyle(fontSize: 16),
              ),
            Text(
              [
                if (start != null) 'Started ${clockTime(start)}',
                if (end != null) 'Ended ${clockTime(end)}',
                'Game clock ${mmss(summary['gameSeconds'] as int? ?? 0)}',
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
                        p['number'] == null
                            ? '${p['name']}'
                            : '${p['number']} · ${p['name']}',
                        mmss(p['secondsPlayed'] as int? ?? 0),
                        (p['goals'] as int? ?? 0) == 0 ? '–' : '${p['goals']}',
                      ),
                    _row(context, 'Total goals', '', '$goals', header: true),
                  ],
                ),
              ),
            ),
            if (absent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Absent: ${absent.map((p) => p['name']).join(', ')}',
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
