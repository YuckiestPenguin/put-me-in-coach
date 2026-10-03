import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/league.dart';
import '../services/cloud_sync.dart';
import '../widgets/counter_row.dart';

/// Create or edit a league's rules. Pass [league] to edit an existing one.
class LeagueEditScreen extends StatefulWidget {
  final League? league;
  const LeagueEditScreen({super.key, this.league});

  @override
  State<LeagueEditScreen> createState() => _LeagueEditScreenState();
}

class _LeagueEditScreenState extends State<LeagueEditScreen> {
  static const _presets = {2: 'Halves', 3: 'Thirds', 4: 'Quarters'};

  late final League _draft = widget.league?.copy() ?? League(name: '');
  late final _nameController = TextEditingController(text: _draft.name);
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.league == null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _draft.name.trim().isEmpty) return;
    _draft.name = _draft.name.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CloudSync(uid).saveLeague(_draft);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save: $e";
        });
      }
    }
  }

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.league?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.league!.name}?'),
        content: const Text('Past games are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CloudSync(uid).deleteLeague(widget.league!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't delete: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = _draft;
    final label = d.periodLabel;
    final canSave = d.name.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New league' : 'Edit league'),
        backgroundColor: scheme.primaryContainer,
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete league',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'League name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => d.name = v),
          ),
          const SizedBox(height: 24),
          Text('Game format', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _presets.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: d.periodCount == e.key,
                  onSelected: (_) => setState(() => d.periodCount = e.key),
                ),
              if (!_presets.containsKey(d.periodCount))
                ChoiceChip(
                  label: Text('Custom (${d.periodCount})'),
                  selected: true,
                  onSelected: (_) {},
                ),
            ],
          ),
          const SizedBox(height: 16),
          CounterRow(
            label: 'Number of ${label.toLowerCase()}s',
            value: '${d.periodCount}',
            onDecrement: () => setState(() {
              if (d.periodCount > 1) d.periodCount--;
            }),
            onIncrement: () => setState(() => d.periodCount++),
          ),
          const SizedBox(height: 12),
          CounterRow(
            label: '$label length',
            value: '${League.fmtMinutes(d.periodMinutes)} min',
            onDecrement: () => setState(() {
              if (d.periodMinutes > 0.5) d.periodMinutes -= 0.5;
            }),
            onIncrement: () => setState(() => d.periodMinutes += 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Total game time: ${League.fmtMinutes(d.totalMinutes)} min',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Text('Players', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          CounterRow(
            label: 'Players on the field',
            value: '${d.playersOnField}',
            onDecrement: () => setState(() {
              if (d.playersOnField > 1) d.playersOnField--;
            }),
            onIncrement: () => setState(() => d.playersOnField++),
          ),
          const SizedBox(height: 24),
          Text('Sub reminders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          CounterRow(
            label: 'Remind me to sub every',
            value: '${League.fmtMinutes(d.subIntervalMinutes)} min',
            onDecrement: () => setState(() {
              if (d.subIntervalMinutes > 0.5) d.subIntervalMinutes -= 0.5;
            }),
            onIncrement: () => setState(() => d.subIntervalMinutes += 0.5),
          ),
          const SizedBox(height: 24),
          Text('Extra player', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow an extra player when trailing'),
            value: d.extraPlayerTrailingBy != null,
            onChanged: (on) =>
                setState(() => d.extraPlayerTrailingBy = on ? 4 : null),
          ),
          if (d.extraPlayerTrailingBy != null)
            CounterRow(
              label: 'Trailing by more than',
              value: '${d.extraPlayerTrailingBy}',
              onDecrement: () => setState(() {
                if (d.extraPlayerTrailingBy! > 1) {
                  d.extraPlayerTrailingBy = d.extraPlayerTrailingBy! - 1;
                }
              }),
              onIncrement: () => setState(
                () => d.extraPlayerTrailingBy = d.extraPlayerTrailingBy! + 1,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}
