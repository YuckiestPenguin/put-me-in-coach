import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/alerts.dart';
import '../util/format.dart';
import '../widgets/game_summary_sheet.dart';
import '../widgets/player_badges.dart';
import '../widgets/player_role_sheet.dart';
import '../widgets/sub_flow_sheet.dart';
import 'settings_screen.dart';

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

  void _confirmEndGame() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End game?'),
        content: const Text(
            'This stops the clock and sub reminders for good. Final playing '
            'times stay on screen to review — start "New game" when ready for '
            'the next one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _state.endGame();
              GameSummarySheet.show(context, _state);
            },
            child: const Text('End game'),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
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
              onSubmitted: (_) =>
                  _submitAddPlayer(ctx, nameController, numberController),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                _submitAddPlayer(ctx, nameController, numberController),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitAddPlayer(BuildContext ctx, TextEditingController name,
      TextEditingController number) {
    if (name.text.trim().isEmpty) return;
    _state.addPlayer(name.text, number: int.tryParse(number.text.trim()));
    Navigator.pop(ctx);
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
              if (v == 'add') _showAddPlayerDialog();
              if (v == 'end') _confirmEndGame();
              if (v == 'summary') GameSummarySheet.show(context, state);
              if (v == 'new') _confirmNewGame();
              if (v == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
              if (v == 'fast') {
                state.subIntervalSeconds =
                    state.subIntervalSeconds == 300 ? 20 : 300;
                state.snoozeAlert();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('Add player')),
              const PopupMenuItem(
                  value: 'settings', child: Text('Game settings')),
              if (!state.gameEnded)
                const PopupMenuItem(value: 'end', child: Text('End game')),
              if (state.gameEnded)
                const PopupMenuItem(
                    value: 'summary', child: Text('Game summary')),
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
          if (state.gameEnded)
            InkWell(
              onTap: () => GameSummarySheet.show(context, state),
              child: Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'Game ended — tap for summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                      PlayerRoleSheet.show(context, state, p.id),
                  leading: CircleAvatar(
                    backgroundColor: p.onField
                        ? const Color(0xFFA5D6A7) // light green: on field
                        : const Color(0xFFFFF59D), // yellow: on bench
                    foregroundColor: Colors.black87,
                    child: Text(p.badgeText,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      Text(p.displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      if (p.isGoalie || p.isFavorite || p.isCaptain) ...[
                        const SizedBox(width: 8),
                        PlayerBadges(player: p, size: 20),
                      ],
                    ],
                  ),
                  subtitle: Text(
                      '${mmss(p.secondsPlayed)} played · ${p.onField ? 'on field' : 'bench'}'),
                  trailing: GestureDetector(
                    onLongPress: () => state.undoGoal(p.id),
                    child: Badge(
                      label: Text('${p.goals}'),
                      isLabelVisible: p.goals > 0,
                      child: IconButton(
                        tooltip: 'Goal! (long-press to undo)',
                        onPressed: () {
                          Alerts.tap();
                          state.addGoal(p.id);
                        },
                        icon: const Text('⚽', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: state.gameEnded
          ? null
          : FloatingActionButton.extended(
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
            '${state.periodLabel} ${state.currentPeriod} of ${state.periodCount}',
            style: TextStyle(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
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
            '${mmss(state.secondsLeftInPeriod)} left in this ${state.periodLabel.toLowerCase()}',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            state.gameEnded
                ? 'Game over'
                : (running
                    ? 'Next sub in ${mmss(state.secondsUntilNextSub)}'
                    : 'On break — clock paused'),
            style: TextStyle(
              color: state.gameEnded
                  ? scheme.error
                  : (running ? scheme.primary : scheme.error),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!state.gameEnded) ...[
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
