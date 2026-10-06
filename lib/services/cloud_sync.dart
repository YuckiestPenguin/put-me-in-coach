import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';

import '../models/game_state.dart';
import '../models/league.dart';
import '../models/team.dart';

/// The coach's data in Firestore, under `users/{uid}`:
///   * `leagues/{id}` — game format and rules
///   * `teams/{id}`   — name, league, roster
///   * `games/{id}`   — one doc per finished game
///   * `team/roster`  — legacy single roster, only read once to migrate it
///
/// The game in progress lives in local storage (it must work offline mid-game);
/// a finished game is written to the cloud, never on clock ticks. Firestore
/// queues writes made offline and sends them later.
class CloudSync {
  final String uid;
  CloudSync(this.uid);

  /// Called with a coach-readable message when a save or delete fails for good
  /// (e.g. rules rejected it). Offline writes don't land here: Firestore
  /// queues them and the games list marks them as not yet synced.
  static void Function(String message)? onError;

  static void _report(String what, Object e, StackTrace st) {
    debugPrint('Cloud sync: $what failed: $e\n$st');
    final detail = e is FirebaseException ? e.code : e;
    onError?.call("Couldn't $what ($detail).");
  }

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

  CollectionReference<Map<String, dynamic>> get _teams =>
      FirebaseFirestore.instance.collection('users/$uid/teams');

  /// All teams, by name.
  Stream<List<Team>> teamsStream() => _teams.snapshots().map((s) {
        final list = [for (final d in s.docs) Team.fromJson(d.id, d.data())];
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Create (no id) or update a team. Rethrows so the editor can report
  /// failures; Firestore queues the write itself when offline.
  Future<void> saveTeam(Team team) async {
    final data = {...team.toJson(), 'updatedAt': FieldValue.serverTimestamp()};
    if (team.id == null) {
      await _teams.add(data);
    } else {
      await _teams.doc(team.id).set(data);
    }
  }

  Future<void> deleteTeam(String id) => _teams.doc(id).delete();

  /// First run after teams were introduced: turn the single saved roster into
  /// a first team called "My Team". Same safeguards as the league migration
  /// (server check, fixed doc id).
  Future<void> _migrateDefaultTeam() async {
    final existing =
        await _teams.limit(1).get(const GetOptions(source: Source.server));
    if (existing.docs.isNotEmpty) return;
    final roster = await _rosterDoc.get(const GetOptions(source: Source.server));
    final players = roster.data()?['players'] as List?;
    if (players == null || players.isEmpty) return;
    await _teams.doc('default').set({
      'name': 'My Team',
      'leagueId': null,
      'players': players,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// One-shot check that Firestore is reachable and readable, for showing why
  /// a screen is stuck loading. Returns a short human-readable result.
  Future<String> probe() async {
    final project = Firebase.app().options.projectId;
    try {
      final snap = await _games
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      return '[$project] Server reachable; read OK (${snap.docs.length} sample game).';
    } on TimeoutException {
      return '[$project] Timed out after 10s waiting for Firestore.';
    } on FirebaseException catch (e, st) {
      debugPrint('Firestore probe failed: ${e.code} ${e.message}\n$st');
      return '[$project] ${e.code}: ${e.message}';
    } catch (e, st) {
      debugPrint('Firestore probe failed: $e\n$st');
      return '[$project] $e';
    }
  }

  /// Finished games, newest first. Includes games saved offline that haven't
  /// reached the server yet.
  /// `pending` is true until the server has acknowledged the game.
  Stream<List<({String id, Map<String, dynamic> data, bool pending})>>
      gamesStream() => _games
          .orderBy('startedAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .map((s) => [
                for (final d in s.docs)
                  (
                    id: d.id,
                    data: d.data(),
                    pending: d.metadata.hasPendingWrites,
                  ),
              ]);

  Future<void> deleteGame(String id) async {
    try {
      await _games.doc(id).delete();
    } catch (e, st) {
      _report('delete the game', e, st);
    }
  }

  /// Connects [state] to the cloud: one-time migrations of pre-existing local
  /// data into leagues and teams, then saving each finished game.
  Future<void> attach(GameState state) async {
    try {
      await _migrateDefaultLeague(state);
    } catch (_) {
      // Offline or rules not deployed: carry on locally.
    }
    try {
      await _migrateDefaultTeam();
    } catch (_) {
      // Same as above; the migration retries on the next launch.
    }
    state.onGameEnded = saveGame;
  }

  void detach(GameState state) {
    state.onGameEnded = null;
  }

  Future<void> saveGame(Map<String, dynamic> summary) async {
    try {
      await _games.add({...summary, 'savedAt': FieldValue.serverTimestamp()});
    } catch (e, st) {
      _report('save the finished game', e, st);
    }
  }
}
