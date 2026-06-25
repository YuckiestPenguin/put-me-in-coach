import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/game_state.dart';
import 'services/persistence.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = GameState();
  state.saver = Persistence.save;
  await Persistence.load(state);
  state.resumeTimerIfNeeded();

  runApp(
    ChangeNotifierProvider.value(value: state, child: const CoachApp()),
  );
}

class CoachApp extends StatelessWidget {
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Put Me In, Coach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Consumer<GameState>(
        builder: (context, state, _) =>
            state.gameStarted ? const GameScreen() : const SetupScreen(),
      ),
    );
  }
}
