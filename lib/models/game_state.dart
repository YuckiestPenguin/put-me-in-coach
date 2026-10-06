import 'dart:async';
import 'package:flutter/foundation.dart';

import 'league.dart';
import 'player.dart';
import 'team.dart';

/// The whole game in one place: roster, clock, fairness tracking, and the
/// 5-minute "sub is due" alert. Extends [ChangeNotifier] so the UI rebuilds
/// whenever anything changes.
///
/// The per-second logic lives in [tick], which is a plain method (not buried in
/// the Timer) so it can be unit-tested directly.
class GameState extends ChangeNotifier {
  final List<Player> roster = [];

  /// How many players should be on the field. Changeable on the fly.
  int onFieldTarget = 7;

  /// True once the coach taps "Start Game" — switches Setup → Game screen.
  bool gameStarted = false;

  /// Whether the game clock is running. Pausing it is a "break" (quarters,
  /// water breaks, etc.) — there is no special halftime concept.
  bool clockRunning = false;

  /// True once the coach ends the game. Freezes the clock and turns off sub
  /// alerts while leaving final playing times on screen for review — unlike
  /// [newGame], which immediately clears them for the next game.
  bool gameEnded = false;

  /// True while the coach is on the setup screen (picking players, starters)
  /// before a game. Not saved: reopening the app lands on the home screen.
  bool settingUp = false;

  /// Start setting up a fresh game from home: no team, league or roster
  /// chosen yet.
  void beginSetup() {
    settingUp = true;
    roster.clear();
    teamId = teamName = leagueId = leagueName = null;
    extraPlayerTrailingBy = null;
    _save();
    notifyListeners();
  }

  void cancelSetup() {
    settingUp = false;
    notifyListeners();
  }

  /// The team and league chosen for this game (null for a one-off game). The
  /// names are kept alongside the ids so a saved game still reads correctly if
  /// the team or league is later renamed or deleted.
  String? teamId;
  String? teamName;
  String? leagueId;
  String? leagueName;

  /// League rule: an extra player is allowed when trailing by more than this.
  int? extraPlayerTrailingBy;

  /// Use [team]'s roster for this game, replacing the current one. Players
  /// start fresh (present, no time or goals); edits made in setup apply to
  /// this game only, never back to the team.
  void applyTeam(Team team) {
    roster
      ..clear()
      ..addAll(team.players.map((p) => Player.fromJson(p.toTeamJson())));
    _sortRoster();
    teamId = team.id;
    teamName = team.name;
    _save();
    notifyListeners();
  }

  /// Back to a one-off game: no team and an empty roster.
  void clearTeam() {
    roster.clear();
    teamId = teamName = null;
    _save();
    notifyListeners();
  }

  /// Take [league]'s rules for this game. They can still be tweaked in game
  /// settings afterwards.
  void applyLeague(League league) {
    periodCount = league.periodCount;
    periodMinutes = league.periodMinutes;
    onFieldTarget = league.playersOnField;
    subIntervalSeconds = (league.subIntervalMinutes * 60).round();
    extraPlayerTrailingBy = league.extraPlayerTrailingBy;
    leagueId = league.id;
    leagueName = league.name;
    _save();
    notifyListeners();
  }

  /// Back to custom rules; the current numbers are kept.
  void clearLeague() {
    leagueId = leagueName = null;
    extraPlayerTrailingBy = null;
    _save();
    notifyListeners();
  }

  /// The signed-in user this device's local data belongs to. Lets us notice
  /// when someone else signs in so their account never receives (or shows)
  /// another coach's roster.
  String? ownerUid;

  /// Called when [uid] signs in. If the local data belongs to a different user
  /// it is wiped first; data with no owner (saved before accounts existed) is
  /// adopted. Detach cloud hooks before calling so the wipe isn't synced.
  void adoptUser(String uid) {
    if (ownerUid != null && ownerUid != uid) _resetLocalData();
    ownerUid = uid;
    _save();
    notifyListeners();
  }

  /// Back to a factory-fresh state: no roster, no game, default settings.
  void _resetLocalData() {
    _timer?.cancel();
    _timer = null;
    roster.clear();
    teamId = teamName = leagueId = leagueName = null;
    extraPlayerTrailingBy = null;
    onFieldTarget = 7;
    gameStarted = false;
    clockRunning = false;
    gameEnded = false;
    settingUp = false;
    startedAt = null;
    endedAt = null;
    gameSeconds = 0;
    subIntervalSeconds = 300;
    lastAlertSecond = 0;
    periodCount = 2;
    periodMinutes = 25;
  }

  /// Wall-clock start and end of the current game, for the summary.
  DateTime? startedAt;
  DateTime? endedAt;

  /// Total elapsed *game* seconds (frozen during breaks).
  int gameSeconds = 0;

  /// Alert cadence. 300s = every 5 minutes. Lowered in debug to test quickly.
  int subIntervalSeconds = 300;

  /// The game-second at which the sub counter last reset (game start or a swap).
  int lastAlertSecond = 0;

  /// How many periods the game is split into (2 = halves, 4 = quarters, etc).
  int periodCount = 2;

  /// How long each period is, in minutes.
  double periodMinutes = 25;

  /// Set by the UI; called from [tick] the moment a sub becomes due so the
  /// screen can chime, vibrate, and pop the swap sheet. Keeps plugins out of
  /// the model.
  VoidCallback? onSubDue;

  Timer? _timer;
  int _ticksSinceSave = 0;

  /// Called once per second by [_timer] (or directly in tests).
  void tick() {
    if (!clockRunning) return;
    gameSeconds++;
    for (final p in roster) {
      if (p.onField) p.secondsPlayed++;
    }
    if (gameSeconds - lastAlertSecond >= subIntervalSeconds) {
      lastAlertSecond = gameSeconds;
      onSubDue?.call();
    }
    if (++_ticksSinceSave >= 5) {
      _ticksSinceSave = 0;
      _save();
    }
    notifyListeners();
  }

  // ---- Setup phase -------------------------------------------------------

  bool hasNumber(int number) => roster.any((p) => p.number == number);

  int _nextId() =>
      roster.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;

  /// Add a player. Name is required (blank is rejected); number is optional
  /// but must be unique among players that have one.
  void addPlayer(String name, {int? number}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (number != null && (number < 0 || hasNumber(number))) return;
    roster.add(Player(id: _nextId(), name: trimmed, number: number));
    _sortRoster();
    _save();
    notifyListeners();
  }

  void _sortRoster() => roster
      .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void removePlayer(int id) {
    roster.removeWhere((p) => p.id == id);
    _save();
    notifyListeners();
  }

  /// Update a player's name (must be non-blank) and optional number. A number
  /// already held by someone else is ignored.
  void editPlayer(int id, String name, int? number) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final p = roster.firstWhere((p) => p.id == id);
    if (number != null && roster.any((o) => o.id != id && o.number == number)) {
      return;
    }
    p.name = trimmed;
    p.number = number;
    _sortRoster();
    _save();
    notifyListeners();
  }

  /// Mark whether a player showed up for the current game. Marking someone
  /// absent also benches them — they can't be absent and on the field.
  void setPresent(int id, bool present) {
    final p = roster.firstWhere((p) => p.id == id);
    p.isPresent = present;
    if (!present) p.onField = false;
    _save();
    notifyListeners();
  }

  /// In setup, toggle whether a player starts the game on the field. A no-op
  /// for absent players — they can't be selected as a starter.
  void toggleStarter(int id) {
    final p = roster.firstWhere((p) => p.id == id);
    if (!p.isPresent) return;
    p.onField = !p.onField;
    _save();
    notifyListeners();
  }

  int get startersCount => roster.where((p) => p.onField).length;

  void addGoal(int id) {
    final p = roster.firstWhere((p) => p.id == id);
    p.goals++;
    _save();
    notifyListeners();
  }

  /// Undo the most recently added goal for a player (corrects a mistaken tap).
  void undoGoal(int id) {
    final p = roster.firstWhere((p) => p.id == id);
    if (p.goals > 0) p.goals--;
    _save();
    notifyListeners();
  }

  /// Assign a role (goalie / captain / favorite). Each role is held by at most
  /// one player, so turning it on for one clears it from everyone else. Tapping
  /// the same player again turns it off.
  void toggleRole(int id, PlayerRole role) {
    final target = roster.firstWhere((p) => p.id == id);
    final turningOn = !target.hasRole(role);
    for (final p in roster) {
      p.setRole(role, false);
    }
    target.setRole(role, turningOn);
    _save();
    notifyListeners();
  }

  void startGame() {
    gameStarted = true;
    settingUp = false;
    startedAt = DateTime.now();
    endedAt = null;
    clockRunning = true;
    gameSeconds = 0;
    lastAlertSecond = 0;
    for (final p in roster) {
      p.secondsPlayed = 0;
      p.goals = 0;
    }
    _startTimer();
    _save();
    notifyListeners();
  }

  // ---- Clock / breaks ----------------------------------------------------

  /// Toggle the game clock. Pausing = taking a break (usable any number of
  /// times); time and the sub counter freeze while paused.
  void togglePlayPause() {
    clockRunning = !clockRunning;
    _save();
    notifyListeners();
  }

  // ---- On-the-fly count --------------------------------------------------

  void incrementTarget() {
    onFieldTarget++;
    _save();
    notifyListeners();
  }

  void decrementTarget() {
    if (onFieldTarget > 1) onFieldTarget--;
    _save();
    notifyListeners();
  }

  // ---- Game format (periods) ---------------------------------------------

  /// The word to use for a period given the current [periodCount] (Half,
  /// Third, Quarter, or a generic Period for anything else).
  String get periodLabel => switch (periodCount) {
        2 => 'Half',
        3 => 'Third',
        4 => 'Quarter',
        _ => 'Period',
      };

  int get periodLengthSeconds => (periodMinutes * 60).round();

  int get totalGameLengthSeconds => periodCount * periodLengthSeconds;

  /// 1-based index of the period the game clock is currently in. Clamped to
  /// [periodCount] so running past the scheduled length still shows the last
  /// period rather than rolling into a nonexistent one.
  int get currentPeriod =>
      (gameSeconds ~/ periodLengthSeconds).clamp(0, periodCount - 1) + 1;

  /// Seconds elapsed within the current period.
  int get secondsIntoPeriod =>
      gameSeconds - (currentPeriod - 1) * periodLengthSeconds;

  /// Seconds remaining in the current period (0 once the game has run past
  /// its scheduled length).
  int get secondsLeftInPeriod =>
      (periodLengthSeconds - secondsIntoPeriod).clamp(0, periodLengthSeconds);

  void setPeriodCount(int count) {
    if (count < 1) return;
    periodCount = count;
    _save();
    notifyListeners();
  }

  void setPeriodMinutes(double minutes) {
    if (minutes < 0.5) return;
    periodMinutes = minutes;
    _save();
    notifyListeners();
  }

  double get subIntervalMinutes => subIntervalSeconds / 60;

  void setSubIntervalMinutes(double minutes) {
    if (minutes < 0.5) return;
    subIntervalSeconds = (minutes * 60).round();
    _save();
    notifyListeners();
  }

  // ---- Substitutions -----------------------------------------------------

  int get fieldCount => roster.where((p) => p.onField).length;

  /// Players currently on the bench, least-played first (the best candidates
  /// to bring on for fair playing time). Absent players are excluded — they
  /// aren't at the game, so they're not sub candidates.
  List<Player> get benchSortedByLeastPlayed {
    final list = roster.where((p) => !p.onField && p.isPresent).toList();
    list.sort((a, b) => a.secondsPlayed.compareTo(b.secondsPlayed));
    return list;
  }

  /// The goalie currently on the field, if there is one.
  Player? get goalieOnField {
    for (final p in roster) {
      if (p.onField && p.isGoalie) return p;
    }
    return null;
  }

  /// Field players who are candidates to come off, most-played first. The
  /// goalie is exempt — keepers aren't rotated on the 5-minute cadence — so
  /// they're left out of the take-off suggestions (the sub sheet still lets you
  /// rotate the goalie deliberately).
  List<Player> get fieldSubCandidates {
    final list = roster.where((p) => p.onField && !p.isGoalie).toList();
    list.sort((a, b) => b.secondsPlayed.compareTo(a.secondsPlayed));
    return list;
  }

  /// Present roster, least-played first — the fairness view shown during a
  /// game. Absent players sat this one out, so they're left off.
  List<Player> get rosterByLeastPlayed {
    final list = roster.where((p) => p.isPresent).toList();
    list.sort((a, b) => a.secondsPlayed.compareTo(b.secondsPlayed));
    return list;
  }

  /// Apply a substitution: [onIds] come on, [offIds] go off. Resets the
  /// sub counter so the next alert is a full interval away. [offIds] may be
  /// shorter than [onIds] (the league allows an extra player when trailing by
  /// more than 4); the on-field target then grows to the new field count.
  void applySwap(List<int> onIds, List<int> offIds) {
    for (final p in roster) {
      if (onIds.contains(p.id)) p.onField = true;
      if (offIds.contains(p.id)) p.onField = false;
    }
    if (fieldCount > onFieldTarget) onFieldTarget = fieldCount;
    lastAlertSecond = gameSeconds;
    _save();
    notifyListeners();
  }

  /// Dismiss the alert without subbing — push the next alert a full interval out.
  void snoozeAlert() {
    lastAlertSecond = gameSeconds;
    notifyListeners();
  }

  int get secondsUntilNextSub =>
      (subIntervalSeconds - (gameSeconds - lastAlertSecond)).clamp(0, subIntervalSeconds);

  // ---- Ending / new game --------------------------------------------------

  /// Stop the game for good: freezes the clock and stops sub alerts, but
  /// leaves the roster and final playing times on screen so the coach can
  /// review them. Call [newGame] afterward to reset for the next game.
  void endGame() {
    clockRunning = false;
    gameEnded = true;
    endedAt = DateTime.now();
    _timer?.cancel();
    _save();
    onGameEnded?.call(summaryJson());
    notifyListeners();
  }

  /// Leave the game screen for the home screen. Clears the current game
  /// like [newGame] (the roster is kept); a finished game is already saved.
  void goHome() {
    newGame();
    settingUp = false;
    notifyListeners();
  }

  /// Back to the setup screen, keeping the roster (names, roles) but clearing
  /// times/field/goals and resetting everyone to present — the coach only
  /// needs to mark exceptions for the next game.
  void newGame() {
    gameStarted = false;
    settingUp = true;
    clockRunning = false;
    gameEnded = false;
    startedAt = null;
    endedAt = null;
    gameSeconds = 0;
    lastAlertSecond = 0;
    for (final p in roster) {
      p.secondsPlayed = 0;
      p.onField = false;
      p.isPresent = true;
      p.goals = 0;
    }
    _timer?.cancel();
    _save();
    notifyListeners();
  }

  // ---- Timer plumbing ----------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Re-arm the timer after restoring a saved in-progress game.
  void resumeTimerIfNeeded() {
    if (gameStarted && !gameEnded && _timer == null) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---- Persistence (wired in main.dart) ----------------------------------

  /// Called once when a game ends, with its summary, so it can be stored.
  void Function(Map<String, dynamic> summary)? onGameEnded;

  /// A plain-data record of the finished game.
  Map<String, dynamic> summaryJson() => {
        'teamId': teamId,
        'teamName': teamName,
        'leagueId': leagueId,
        'leagueName': leagueName,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'gameSeconds': gameSeconds,
        'players': [
          for (final p in roster)
            {
              'name': p.name,
              'number': p.number,
              'present': p.isPresent,
              'secondsPlayed': p.secondsPlayed,
              'goals': p.goals,
            }
        ],
      };

  /// Injected saver, so the model itself stays free of shared_preferences.
  Future<void> Function(GameState state)? saver;
  void _save() => saver?.call(this);

  Map<String, dynamic> toJson() => {
        'onFieldTarget': onFieldTarget,
        'gameStarted': gameStarted,
        'clockRunning': clockRunning,
        'gameEnded': gameEnded,
        'ownerUid': ownerUid,
        'teamId': teamId,
        'teamName': teamName,
        'leagueId': leagueId,
        'leagueName': leagueName,
        'extraPlayerTrailingBy': extraPlayerTrailingBy,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'gameSeconds': gameSeconds,
        'subIntervalSeconds': subIntervalSeconds,
        'lastAlertSecond': lastAlertSecond,
        'periodCount': periodCount,
        'periodMinutes': periodMinutes,
        'roster': roster.map((p) => p.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    onFieldTarget = json['onFieldTarget'] as int? ?? 7;
    gameStarted = json['gameStarted'] as bool? ?? false;
    clockRunning = json['clockRunning'] as bool? ?? false;
    gameEnded = json['gameEnded'] as bool? ?? false;
    ownerUid = json['ownerUid'] as String?;
    teamId = json['teamId'] as String?;
    teamName = json['teamName'] as String?;
    leagueId = json['leagueId'] as String?;
    leagueName = json['leagueName'] as String?;
    extraPlayerTrailingBy = json['extraPlayerTrailingBy'] as int?;
    startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    endedAt = DateTime.tryParse(json['endedAt'] as String? ?? '');
    gameSeconds = json['gameSeconds'] as int? ?? 0;
    subIntervalSeconds = json['subIntervalSeconds'] as int? ?? 300;
    lastAlertSecond = json['lastAlertSecond'] as int? ?? 0;
    periodCount = json['periodCount'] as int? ?? 2;
    periodMinutes = (json['periodMinutes'] as num?)?.toDouble() ?? 25;
    roster
      ..clear()
      ..addAll(
        (json['roster'] as List? ?? [])
            .map((e) => Player.fromJson(e as Map<String, dynamic>)),
      );
    notifyListeners();
  }
}
