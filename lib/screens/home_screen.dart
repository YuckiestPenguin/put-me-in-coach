import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import 'history_screen.dart';
import 'leagues_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'teams_screen.dart';

/// Landing screen: past games and a button to start a new one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => OnboardingScreen.showIfFirstTime(context));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Put Me In, Coach'),
        backgroundColor: scheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'How it works',
            icon: const Icon(Icons.help_outline),
            onPressed: () => OnboardingScreen.show(context),
          ),
          IconButton(
            tooltip: 'Teams',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TeamsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Leagues',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LeaguesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: context.read<GameState>().beginSetup,
                icon: const Icon(Icons.add),
                label: const Text('New game'),
              ),
            ),
          ),
          const Divider(height: 1),
          const Expanded(child: GameHistoryList()),
        ],
      ),
    );
  }
}
