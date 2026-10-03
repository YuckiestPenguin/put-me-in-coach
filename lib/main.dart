import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase/firebase_options_dev.dart';
import 'firebase/firebase_options_prod.dart';
import 'models/game_state.dart';
import 'services/persistence.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';

/// Which Firebase project to use: `--dart-define=ENV=prod` for release builds,
/// otherwise dev.
const _env = String.fromEnvironment('ENV', defaultValue: 'dev');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _env == 'prod'
        ? ProdFirebaseOptions.currentPlatform
        : DevFirebaseOptions.currentPlatform,
  );

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
