import 'package:firebase_auth/firebase_auth.dart' hide Persistence;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase/firebase_options_dev.dart';
import 'firebase/firebase_options_prod.dart';
import 'models/game_state.dart';
import 'services/cloud_sync.dart';
import 'services/persistence.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
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

class CoachApp extends StatefulWidget {
  const CoachApp({super.key});

  @override
  State<CoachApp> createState() => _CoachAppState();
}

class _CoachAppState extends State<CoachApp> {
  CloudSync? _sync;
  String? _syncedUid;

  /// Starts (or stops) cloud sync when the signed-in user changes.
  void _onUser(GameState state, User? user) {
    if (user?.uid == _syncedUid) return;
    _sync?.detach(state);
    _syncedUid = user?.uid;
    _sync = null;
    if (user == null) return;
    // Detach first (above) so wiping another user's local data isn't synced.
    state.adoptUser(user.uid);
    _sync = CloudSync(user.uid);
    _sync!.attach(state);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<GameState>();
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = snap.data;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onUser(state, user));
          if (user == null) return const SignInScreen();
          return Consumer<GameState>(
            builder: (context, state, _) => state.gameStarted
                ? const GameScreen()
                : state.settingUp
                    ? const SetupScreen()
                    : const HomeScreen(),
          );
        },
      ),
    );
  }
}
