import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../widgets/player_badges.dart';
import '../widgets/player_role_sheet.dart';
import 'settings_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _add(GameState state) {
    if (_nameController.text.trim().isEmpty) {
      _nameFocus.requestFocus();
      return;
    }
    state.addPlayer(_nameController.text,
        number: int.tryParse(_numberController.text.trim()));
    _numberController.clear();
    _nameController.clear();
    _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final starters = state.startersCount;
    final canStart = state.roster.isNotEmpty && starters > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Put Me In, Coach'),
        backgroundColor: scheme.primaryContainer,
        leading: BackButton(onPressed: state.cancelSetup),
        actions: [
          IconButton(
            tooltip: 'Game settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Players on the field ------------------------------------
          Text('Players on the field',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                iconSize: 32,
                onPressed: state.decrementTarget,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '${state.onFieldTarget}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              IconButton.filledTonal(
                iconSize: 32,
                onPressed: state.incrementTarget,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Add players ---------------------------------------------
          Text('Roster', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _numberFocus.requestFocus(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numberController,
                  focusNode: _numberFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _add(state),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _add(state),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (state.roster.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Add your players by name to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
            )
          else ...[
            Text(
              'Tap a player to start them on the field (green) or leave them '
              'on the bench (yellow). Long-press to mark absent, rename, or '
              'set goalie 🧤, favorite ⭐, or captain C.',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in state.roster)
                  GestureDetector(
                    onLongPress: () =>
                        PlayerRoleSheet.show(context, state, p.id),
                    child: InputChip(
                      isEnabled: p.isPresent,
                      selected: p.onField,
                      showCheckmark: true,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.number == null
                                ? p.displayName
                                : '${p.number} · ${p.displayName}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (p.isGoalie || p.isFavorite || p.isCaptain) ...[
                            const SizedBox(width: 5),
                            PlayerBadges(player: p, size: 15),
                          ],
                        ],
                      ),
                      selectedColor: const Color(0xFFA5D6A7), // light green
                      backgroundColor:
                          p.isPresent ? const Color(0xFFFFF59D) : null, // yellow
                      labelStyle: const TextStyle(color: Colors.black87),
                      onSelected: (_) => state.toggleStarter(p.id),
                      onDeleted: () => state.removePlayer(p.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$starters of ${state.onFieldTarget} on the field',
                style: TextStyle(
                  color: starters == state.onFieldTarget
                      ? scheme.primary
                      : scheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canStart
                      ? () {
                          FocusScope.of(context).unfocus();
                          state.startGame();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Game',
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
