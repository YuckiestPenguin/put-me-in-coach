import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_state.dart';

/// Backs the coach's data up to Firestore under `users/{uid}`:
///   * `users/{uid}/team/roster` — one doc holding the roster
///   * `users/{uid}/games/{id}`  — one doc per finished game
///
/// Local storage stays the source of truth during a game (it works offline);
/// the cloud copy is written only on roster edits and at end of game, never on
/// clock ticks. Firestore queues writes made offline and sends them later.
class CloudSync {
  final String uid;
  CloudSync(this.uid);

  DocumentReference<Map<String, dynamic>> get _rosterDoc =>
      FirebaseFirestore.instance.doc('users/$uid/team/roster');

  CollectionReference<Map<String, dynamic>> get _games =>
      FirebaseFirestore.instance.collection('users/$uid/games');

  /// Connects [state] to the cloud. If this device has no roster yet but the
  /// cloud does (new device / reinstall), the cloud roster is loaded;
  /// otherwise this device's roster is what gets saved.
  Future<void> attach(GameState state) async {
    try {
      if (state.roster.isEmpty) {
        final snap = await _rosterDoc.get();
        final players = snap.data()?['players'] as List?;
        if (players != null && players.isNotEmpty) {
          state.loadTeamFromJson(players);
        }
      } else {
        await pushRoster(state);
      }
    } catch (_) {
      // Offline or rules not deployed: carry on locally.
    }
    state.onRosterChanged = () => pushRoster(state);
    state.onGameEnded = saveGame;
  }

  void detach(GameState state) {
    state.onRosterChanged = null;
    state.onGameEnded = null;
  }

  Future<void> pushRoster(GameState state) async {
    try {
      await _rosterDoc.set({
        'players': state.rosterToTeamJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> saveGame(Map<String, dynamic> summary) async {
    try {
      await _games.add({...summary, 'savedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }
}
