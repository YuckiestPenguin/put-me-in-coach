import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/league.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/cloud_sync.dart';
import '../widgets/player_badges.dart';

/// Create or edit a team: name (required), league (optional), and roster.
/// Pass [team] to edit an existing one.
class TeamEditScreen extends StatefulWidget {
  final Team? team;
  const TeamEditScreen({super.key, this.team});

  @override
  State<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends State<TeamEditScreen> {
  late final Team _draft = widget.team?.copy() ?? Team(name: '');
  late final _nameController = TextEditingController(text: _draft.name);
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.team == null;

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
      await CloudSync(uid).saveTeam(_draft);
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
    if (uid == null || widget.team?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.team!.name}?'),
        content: const Text('Its roster is removed. Past games are kept.'),
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
    if (ok != true) return;
    try {
      await CloudSync(uid).deleteTeam(widget.team!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't delete: $e");
    }
  }

  /// Add (null [player]) or edit a player in the draft roster.
  Future<void> _editPlayer([Player? player]) async {
    final result = await showDialog<_PlayerEdit>(
      context: context,
      builder: (_) => _PlayerDialog(team: _draft, player: player),
    );
    if (result == null) return;
    setState(() {
      if (result.remove) {
        _draft.players.removeWhere((p) => p.id == player!.id);
      } else if (player == null) {
        _draft.players.add(Player(
            id: _draft.nextPlayerId(),
            name: result.name,
            number: result.number));
        final added = _draft.players.last;
        for (final role in result.roles) {
          _draft.toggleRole(added.id, role);
        }
      } else {
        player.name = result.name;
        player.number = result.number;
        for (final role in PlayerRole.values) {
          if (player.hasRole(role) != result.roles.contains(role)) {
            _draft.toggleRole(player.id, role);
          }
        }
      }
      _draft.sortPlayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final canSave = _draft.name.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New team' : 'Edit team'),
        backgroundColor: scheme.primaryContainer,
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete team',
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
              labelText: 'Team name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _draft.name = v),
          ),
          const SizedBox(height: 16),
          if (uid != null)
            StreamBuilder<List<League>>(
              stream: CloudSync(uid).leaguesStream(),
              builder: (context, snap) {
                final leagues = snap.data ?? <League>[];
                // A league that was deleted shows as "No league".
                final value =
                    leagues.any((l) => l.id == _draft.leagueId)
                        ? _draft.leagueId
                        : null;
                return DropdownButtonFormField<String?>(
                  initialValue: value,
                  decoration: const InputDecoration(
                    labelText: 'League (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No league')),
                    for (final l in leagues)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setState(() => _draft.leagueId = v),
                );
              },
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Roster (${_draft.players.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: () => _editPlayer(),
                icon: const Icon(Icons.add),
                label: const Text('Add player'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_draft.players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No players yet.',
                  style: TextStyle(color: scheme.outline)),
            )
          else
            for (final p in _draft.players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(p.badgeText)),
                title: Row(
                  children: [
                    Flexible(child: Text(p.displayName)),
                    const SizedBox(width: 8),
                    PlayerBadges(player: p, size: 16),
                  ],
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editPlayer(p),
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

/// What the player dialog returns.
class _PlayerEdit {
  final String name;
  final int? number;
  final Set<PlayerRole> roles;
  final bool remove;
  _PlayerEdit(this.name, this.number, this.roles, {this.remove = false});
}

class _PlayerDialog extends StatefulWidget {
  final Team team;
  final Player? player;
  const _PlayerDialog({required this.team, this.player});

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  late final _name = TextEditingController(text: widget.player?.name ?? '');
  late final _number =
      TextEditingController(text: widget.player?.number?.toString() ?? '');
  late final Set<PlayerRole> _roles = {
    for (final r in PlayerRole.values)
      if (widget.player?.hasRole(r) ?? false) r,
  };
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final number = int.tryParse(_number.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (number != null &&
        widget.team.numberTaken(number, exceptId: widget.player?.id)) {
      setState(() => _error = 'Number $number is already used');
      return;
    }
    Navigator.pop(context, _PlayerEdit(name, number, _roles));
  }

  static const _roleLabels = {
    PlayerRole.goalie: '🧤 Goalie',
    PlayerRole.captain: 'Captain',
    PlayerRole.favorite: '⭐ Favorite',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.player == null ? 'Add player' : 'Edit player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number (optional)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final r in PlayerRole.values)
                  FilterChip(
                    label: Text(_roleLabels[r]!),
                    selected: _roles.contains(r),
                    onSelected: (on) =>
                        setState(() => on ? _roles.add(r) : _roles.remove(r)),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.player != null)
          TextButton(
            onPressed: () => Navigator.pop(
                context, _PlayerEdit('', null, const {}, remove: true)),
            child: Text('Remove',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
