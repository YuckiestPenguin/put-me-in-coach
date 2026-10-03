import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../util/format.dart';
import '../widgets/counter_row.dart';

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
          CounterRow(
            label: 'Number of ${state.periodLabel.toLowerCase()}s',
            value: '${state.periodCount}',
            onDecrement: () => state.setPeriodCount(state.periodCount - 1),
            onIncrement: () => state.setPeriodCount(state.periodCount + 1),
          ),
          const SizedBox(height: 12),
          CounterRow(
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
          CounterRow(
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
