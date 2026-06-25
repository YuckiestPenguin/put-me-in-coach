import 'dart:async';
import 'package:flutter/foundation.dart';

import 'player.dart';

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

  /// Total elapsed *game* seconds (frozen during breaks).
  int gameSeconds = 0;

  /// Alert cadence. 300s = every 5 minutes. Lowered in debug to test quickly.
  int subIntervalSeconds = 300;

  /// The game-second at which the sub counter last reset (game start or a swap).
  int lastAlertSecond = 0;

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

  void addPlayer(int number) {
    if (number <= 0 || hasNumber(number)) return;
    roster.add(Player(number: number));
    roster.sort((a, b) => a.number.compareTo(b.number));
    _save();
    notifyListeners();
  }

  void removePlayer(int number) {
    roster.removeWhere((p) => p.number == number);
    _save();
    notifyListeners();
  }

  /// In setup, toggle whether a number starts the game on the field.
  void toggleStarter(int number) {
    final p = roster.firstWhere((p) => p.number == number);
    p.onField = !p.onField;
    _save();
    notifyListeners();
  }

  int get startersCount => roster.where((p) => p.onField).length;

  void startGame() {
    gameStarted = true;
    clockRunning = true;
    gameSeconds = 0;
    lastAlertSecond = 0;
    for (final p in roster) {
      p.secondsPlayed = 0;
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

  // ---- Substitutions -----------------------------------------------------

  int get fieldCount => roster.where((p) => p.onField).length;

  /// Players currently on the bench, least-played first (the best candidates
  /// to bring on for fair playing time).
  List<Player> get benchSortedByLeastPlayed {
    final list = roster.where((p) => !p.onField).toList();
    list.sort((a, b) => a.secondsPlayed.compareTo(b.secondsPlayed));
    return list;
  }

  /// Players currently on the field, most-played first (the best candidates to
  /// give a rest).
  List<Player> get fieldSortedByMostPlayed {
    final list = roster.where((p) => p.onField).toList();
    list.sort((a, b) => b.secondsPlayed.compareTo(a.secondsPlayed));
    return list;
  }

  /// Whole roster, least-played first — the fairness view.
  List<Player> get rosterByLeastPlayed {
    final list = [...roster];
    list.sort((a, b) => a.secondsPlayed.compareTo(b.secondsPlayed));
    return list;
  }

  /// Apply a substitution: [onNumbers] come on, [offNumbers] go off. Resets the
  /// sub counter so the next alert is a full interval away.
  void applySwap(List<int> onNumbers, List<int> offNumbers) {
    for (final p in roster) {
      if (onNumbers.contains(p.number)) p.onField = true;
      if (offNumbers.contains(p.number)) p.onField = false;
    }
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

  // ---- New game ----------------------------------------------------------

  /// Back to the setup screen, keeping the roster but clearing times/field.
  void newGame() {
    gameStarted = false;
    clockRunning = false;
    gameSeconds = 0;
    lastAlertSecond = 0;
    for (final p in roster) {
      p.secondsPlayed = 0;
      p.onField = false;
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
    if (gameStarted && _timer == null) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---- Persistence (wired in main.dart) ----------------------------------

  /// Injected saver, so the model itself stays free of shared_preferences.
  Future<void> Function(GameState state)? saver;
  void _save() => saver?.call(this);

  Map<String, dynamic> toJson() => {
        'onFieldTarget': onFieldTarget,
        'gameStarted': gameStarted,
        'clockRunning': clockRunning,
        'gameSeconds': gameSeconds,
        'subIntervalSeconds': subIntervalSeconds,
        'lastAlertSecond': lastAlertSecond,
        'roster': roster.map((p) => p.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    onFieldTarget = json['onFieldTarget'] as int? ?? 7;
    gameStarted = json['gameStarted'] as bool? ?? false;
    clockRunning = json['clockRunning'] as bool? ?? false;
    gameSeconds = json['gameSeconds'] as int? ?? 0;
    subIntervalSeconds = json['subIntervalSeconds'] as int? ?? 300;
    lastAlertSecond = json['lastAlertSecond'] as int? ?? 0;
    roster
      ..clear()
      ..addAll(
        (json['roster'] as List? ?? [])
            .map((e) => Player.fromJson(e as Map<String, dynamic>)),
      );
    notifyListeners();
  }
}
