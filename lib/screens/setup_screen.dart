import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../widgets/player_badges.dart';
import '../widgets/player_role_sheet.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(GameState state) {
    final n = int.tryParse(_controller.text.trim());
    if (n != null) {
      state.addPlayer(n);
    }
    _controller.clear();
    _focus.requestFocus();
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Player number',
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
                'Add your players by number to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
            )
          else ...[
            Text(
              'Tap a number to put it on the field to start. '
              'Long-press to set goalie 🧤, favorite ⭐, or captain C.',
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
                        PlayerRoleSheet.show(context, state, p.number),
                    child: InputChip(
                      selected: p.onField,
                      showCheckmark: true,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${p.number}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (p.isGoalie || p.isFavorite || p.isCaptain) ...[
                            const SizedBox(width: 5),
                            PlayerBadges(player: p, size: 15),
                          ],
                        ],
                      ),
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(
                        color:
                            p.onField ? scheme.onPrimary : scheme.onSurface,
                      ),
                      onSelected: (_) => state.toggleStarter(p.number),
                      onDeleted: () => state.removePlayer(p.number),
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
