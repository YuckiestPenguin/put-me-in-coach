import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_state.dart';
import '../models/league.dart';

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

  CollectionReference<Map<String, dynamic>> get _leagues =>
      FirebaseFirestore.instance.collection('users/$uid/leagues');

  /// All leagues, by name.
  Stream<List<League>> leaguesStream() => _leagues.snapshots().map((s) {
        final list = [for (final d in s.docs) League.fromJson(d.id, d.data())];
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Create (no id) or update a league. Rethrows so the editor can report
  /// failures; Firestore queues the write itself when offline.
  Future<void> saveLeague(League league) async {
    final data = {...league.toJson(), 'updatedAt': FieldValue.serverTimestamp()};
    if (league.id == null) {
      await _leagues.add(data);
    } else {
      await _leagues.doc(league.id).set(data);
    }
  }

  Future<void> deleteLeague(String id) => _leagues.doc(id).delete();

  /// First run after leagues were introduced: turn the settings this device
  /// was already using into a "Default" league. Checks the server (not the
  /// cache) so an offline start can't create a duplicate, and uses a fixed doc
  /// id so two devices racing can't create two.
  Future<void> _migrateDefaultLeague(GameState state) async {
    final existing =
        await _leagues.limit(1).get(const GetOptions(source: Source.server));
    if (existing.docs.isNotEmpty) return;
    await _leagues.doc('default').set({
      ...League(
        name: 'Default',
        periodCount: state.periodCount,
        periodMinutes: state.periodMinutes,
        playersOnField: state.onFieldTarget,
        subIntervalMinutes: state.subIntervalMinutes,
      ).toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Finished games, newest first. Includes games saved offline that haven't
  /// reached the server yet.
  Stream<List<({String id, Map<String, dynamic> data})>> gamesStream() =>
      _games.orderBy('startedAt', descending: true).snapshots().map((s) => [
            for (final d in s.docs) (id: d.id, data: d.data()),
          ]);

  Future<void> deleteGame(String id) async {
    try {
      await _games.doc(id).delete();
    } catch (_) {}
  }

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
    try {
      await _migrateDefaultLeague(state);
    } catch (_) {}
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
