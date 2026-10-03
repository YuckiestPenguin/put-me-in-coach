import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../util/format.dart';

/// Lets the coach configure the game format: how many periods (halves,
/// quarters, or a custom split) and how long each one is, plus the sub
/// reminder cadence.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _presets = {2: 'Halves', 3: 'Thirds', 4: 'Quarters'};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final isPreset = _presets.containsKey(state.periodCount);
    final totalMinutes = state.periodCount * state.periodMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings'),
        backgroundColor: scheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle),
            title: Text(FirebaseAuth.instance.currentUser?.email ?? 'Signed in'),
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Sign out'),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text('Game format', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _presets.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: state.periodCount == entry.key,
                  onSelected: (_) => state.setPeriodCount(entry.key),
                ),
              if (!isPreset)
                ChoiceChip(label: Text('Custom (${state.periodCount})'), selected: true, onSelected: (_) {}),
            ],
          ),
          const SizedBox(height: 20),
          _CounterRow(
            label: 'Number of ${state.periodLabel.toLowerCase()}s',
            value: '${state.periodCount}',
            onDecrement: () => state.setPeriodCount(state.periodCount - 1),
            onIncrement: () => state.setPeriodCount(state.periodCount + 1),
          ),
          const SizedBox(height: 12),
          _CounterRow(
            label: '${state.periodLabel} length',
            value: '${state.periodMinutes} min',
            onDecrement: () => state.setPeriodMinutes(state.periodMinutes - 1),
            onIncrement: () => state.setPeriodMinutes(state.periodMinutes + 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Total game time: ${mmss(totalMinutes * 60)} ($totalMinutes min)',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Text('Sub reminders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _CounterRow(
            label: 'Remind me to sub every',
            value: '${state.subIntervalMinutes} min',
            onDecrement: () =>
                state.setSubIntervalMinutes(state.subIntervalMinutes - 1),
            onIncrement: () =>
                state.setSubIntervalMinutes(state.subIntervalMinutes + 1),
          ),
        ],
      ),
    );
  }
}

/// A labeled value with +/- steppers, styled like the on-field-count control
/// on the setup screen.
class _CounterRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        IconButton.filledTonal(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 72,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
