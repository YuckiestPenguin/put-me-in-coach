import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/alerts.dart';
import '../util/format.dart';
import '../widgets/player_badges.dart';
import '../widgets/player_role_sheet.dart';
import '../widgets/sub_flow_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _state;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _state = context.read<GameState>();
    _state.onSubDue = _handleSubDue;
    Alerts.keepAwake(true);
  }

  @override
  void dispose() {
    _state.onSubDue = null;
    Alerts.keepAwake(false);
    super.dispose();
  }

  Future<void> _handleSubDue() async {
    if (!mounted || _sheetOpen) return;
    await Alerts.subDue();
    _openSubSheet(triggeredByAlert: true);
  }

  Future<void> _openSubSheet({required bool triggeredByAlert}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await SubFlowSheet.show(context, _state,
        triggeredByAlert: triggeredByAlert);
    _sheetOpen = false;
  }

  void _confirmNewGame() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New game?'),
        content: const Text(
            'This clears all playing times and returns to setup. Your roster is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _state.newGame();
            },
            child: const Text('New game'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final fieldList = state.rosterByLeastPlayed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Put Me In, Coach'),
        backgroundColor: scheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'new') _confirmNewGame();
              if (v == 'fast') {
                state.subIntervalSeconds =
                    state.subIntervalSeconds == 300 ? 20 : 300;
                state.snoozeAlert();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new', child: Text('New game')),
              PopupMenuItem(
                value: 'fast',
                child: Text(state.subIntervalSeconds == 300
                    ? 'Debug: fast sub timer (20s)'
                    : 'Debug: normal sub timer (5m)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _ClockPanel(state: state),
          const Divider(height: 1),
          _FieldCountBar(state: state),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: fieldList.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = fieldList[i];
                return ListTile(
                  onTap: () =>
                      PlayerRoleSheet.show(context, state, p.number),
                  leading: CircleAvatar(
                    backgroundColor:
                        p.onField ? scheme.primary : scheme.surfaceContainerHighest,
                    foregroundColor:
                        p.onField ? scheme.onPrimary : scheme.onSurface,
                    child: Text('${p.number}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      Text(mmss(p.secondsPlayed),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      if (p.isGoalie || p.isFavorite || p.isCaptain) ...[
                        const SizedBox(width: 8),
                        PlayerBadges(player: p, size: 20),
                      ],
                    ],
                  ),
                  subtitle: const Text('played'),
                  trailing: p.onField
                      ? Chip(
                          label: const Text('ON FIELD'),
                          backgroundColor: scheme.primaryContainer,
                          visualDensity: VisualDensity.compact,
                        )
                      : Chip(
                          label: const Text('bench'),
                          visualDensity: VisualDensity.compact,
                        ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSubSheet(triggeredByAlert: false),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Make Sub'),
      ),
    );
  }
}

/// The big game clock, play/pause (break), and countdown to the next sub.
class _ClockPanel extends StatelessWidget {
  final GameState state;
  const _ClockPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = state.clockRunning;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Text(
            mmss(state.gameSeconds),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.onSurface,
            ),
          ),
          Text(
            running
                ? 'Next sub in ${mmss(state.secondsUntilNextSub)}'
                : 'On break — clock paused',
            style: TextStyle(
              color: running ? scheme.primary : scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: state.togglePlayPause,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? 'Take a break' : 'Resume game',
                  style: const TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The on-the-fly "players on field" control plus the live on/target count.
class _FieldCountBar extends StatelessWidget {
  final GameState state;
  const _FieldCountBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onField = state.fieldCount;
    final matched = onField == state.onFieldTarget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('On field', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text(
            '$onField / ${state.onFieldTarget}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: matched ? scheme.primary : scheme.error,
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: state.decrementTarget,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: state.incrementTarget,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
