import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../services/alerts.dart';
import '../util/format.dart';
import 'player_badges.dart';

/// The two-step substitution flow shown as a modal sheet:
///   Step 1 — pick bench players to bring ON  (least-played surfaced first)
///   Step 2 — pick field players to take OFF  (most-played surfaced first)
/// Confirm applies the swap. Counts must match so the on-field number stays put;
/// change the number itself with the +/- control on the game screen.
class SubFlowSheet extends StatefulWidget {
  final GameState state;

  /// True when opened by the 5-minute alert (so dismissing snoozes the timer).
  final bool triggeredByAlert;

  const SubFlowSheet({
    super.key,
    required this.state,
    required this.triggeredByAlert,
  });

  static Future<void> show(
    BuildContext context,
    GameState state, {
    required bool triggeredByAlert,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: !triggeredByAlert,
      builder: (_) => SubFlowSheet(
        state: state,
        triggeredByAlert: triggeredByAlert,
      ),
    );
  }

  @override
  State<SubFlowSheet> createState() => _SubFlowSheetState();
}

class _SubFlowSheetState extends State<SubFlowSheet> {
  int _step = 1; // 1 = bring on, 2 = take off
  final Set<int> _on = {};
  final Set<int> _off = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bringingOn = _step == 1;
    final players =
        bringingOn ? widget.state.benchSortedByLeastPlayed : widget.state.fieldSortedByMostPlayed;
    final selected = bringingOn ? _on : _off;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(bringingOn ? Icons.login : Icons.logout,
                  color: bringingOn ? scheme.primary : scheme.error),
              const SizedBox(width: 8),
              Text(
                bringingOn ? 'Bring on' : 'Take off',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text('Step $_step of 2',
                  style: TextStyle(color: scheme.outline)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            bringingOn
                ? 'Subs who have played the least are first.'
                : 'Players who have played the most are first.',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                bringingOn
                    ? 'No players on the bench.'
                    : 'No players on the field.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in players)
                      _PlayerToggle(
                        player: p,
                        selected: selected.contains(p.number),
                        accent: bringingOn ? scheme.primary : scheme.error,
                        onTap: () {
                          Alerts.tap();
                          setState(() {
                            if (selected.contains(p.number)) {
                              selected.remove(p.number);
                            } else {
                              selected.add(p.number);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          _buildActions(context, scheme),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ColorScheme scheme) {
    if (_step == 1) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                if (widget.triggeredByAlert) widget.state.snoozeAlert();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _on.isEmpty
                  ? null
                  : () => setState(() => _step = 2),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Next  (${_on.length} on)'),
            ),
          ),
        ],
      );
    }

    final matched = _off.length == _on.length;
    return Column(
      children: [
        if (!matched)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Pick ${_on.length} to take off (selected ${_off.length}).',
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: matched
                    ? () {
                        widget.state.applySwap(_on.toList(), _off.toList());
                        Navigator.of(context).pop();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirm Swap'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A large number tile used inside the sub flow.
class _PlayerToggle extends StatelessWidget {
  final Player player;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _PlayerToggle({
    required this.player,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 16,
              child: PlayerBadges(player: player, size: 14),
            ),
            Text(
              '${player.number}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mmss(player.secondsPlayed),
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.9)
                    : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
