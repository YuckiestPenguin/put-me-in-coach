import 'package:flutter_test/flutter_test.dart';
import 'package:put_me_in_coach/models/game_state.dart';
import 'package:put_me_in_coach/models/player.dart';

void main() {
  int idOf(GameState g, int number) =>
      g.roster.firstWhere((p) => p.number == number).id;

  GameState freshGame() {
    final g = GameState();
    g.onFieldTarget = 2;
    g.addPlayer('Seven', number: 7);
    g.addPlayer('Ten', number: 10);
    g.addPlayer('Three', number: 3);
    g.toggleStarter(idOf(g, 7)); // 7 and 10 start on the field
    g.toggleStarter(idOf(g, 10));
    g.startGame();
    return g;
  }

  test('only on-field players accrue time while the clock runs', () {
    final g = freshGame();
    for (var i = 0; i < 10; i++) {
      g.tick();
    }
    expect(g.gameSeconds, 10);
    expect(g.roster.firstWhere((p) => p.number == 7).secondsPlayed, 10);
    expect(g.roster.firstWhere((p) => p.number == 10).secondsPlayed, 10);
    expect(g.roster.firstWhere((p) => p.number == 3).secondsPlayed, 0);
  });

  test('a break (pause) freezes the clock and per-player time', () {
    final g = freshGame();
    for (var i = 0; i < 5; i++) {
      g.tick();
    }
    g.togglePlayPause(); // break
    for (var i = 0; i < 100; i++) {
      g.tick();
    }
    expect(g.gameSeconds, 5);
    g.togglePlayPause(); // resume
    g.tick();
    expect(g.gameSeconds, 6);
  });

  test('sub alert fires at the interval and resets', () {
    final g = freshGame();
    g.subIntervalSeconds = 5;
    var alerts = 0;
    g.onSubDue = () => alerts++;
    for (var i = 0; i < 12; i++) {
      g.tick();
    }
    expect(alerts, 2); // at second 5 and second 10
  });

  test('swap moves players and resets the sub counter', () {
    final g = freshGame();
    g.subIntervalSeconds = 300;
    for (var i = 0; i < 100; i++) {
      g.tick();
    }
    g.applySwap([idOf(g, 3)], [idOf(g, 7)]); // bring on 3, take off 7
    expect(g.roster.firstWhere((p) => p.number == 3).onField, true);
    expect(g.roster.firstWhere((p) => p.number == 7).onField, false);
    expect(g.secondsUntilNextSub, 300); // counter reset on swap
    expect(g.fieldCount, 2); // still two on the field
  });

  test('a role is single-assignment — moving it clears the previous holder', () {
    final g = freshGame();
    g.toggleRole(idOf(g, 7), PlayerRole.goalie);
    expect(g.roster.firstWhere((p) => p.number == 7).isGoalie, true);

    // Assigning goalie to 10 must take it away from 7.
    g.toggleRole(idOf(g, 10), PlayerRole.goalie);
    expect(g.roster.firstWhere((p) => p.number == 7).isGoalie, false);
    expect(g.roster.firstWhere((p) => p.number == 10).isGoalie, true);
    expect(g.roster.where((p) => p.isGoalie).length, 1);

    // Tapping the same player again clears the role entirely.
    g.toggleRole(idOf(g, 10), PlayerRole.goalie);
    expect(g.roster.where((p) => p.isGoalie).length, 0);

    // Roles are independent: captain and favorite can coexist on a player.
    g.toggleRole(idOf(g, 3), PlayerRole.captain);
    g.toggleRole(idOf(g, 3), PlayerRole.favorite);
    final p3 = g.roster.firstWhere((p) => p.number == 3);
    expect(p3.isCaptain && p3.isFavorite, true);
  });

  test('fairness sorting surfaces least-played on the bench', () {
    final g = freshGame();
    for (var i = 0; i < 30; i++) {
      g.tick();
    }
    // 3 is on the bench with 0 minutes; it should be first to bring on.
    expect(g.benchSortedByLeastPlayed.first.number, 3);
    // 7 and 10 have the most time; either is a valid first take-off.
    expect(g.fieldSubCandidates.first.secondsPlayed, 30);
  });

  test('the goalie is exempt from take-off suggestions', () {
    final g = freshGame();
    g.toggleRole(idOf(g, 7), PlayerRole.goalie); // 7 is on the field
    for (var i = 0; i < 30; i++) {
      g.tick();
    }
    // 7 is on the field but, as goalie, must not be a take-off candidate.
    expect(g.fieldSubCandidates.any((p) => p.number == 7), false);
    expect(g.fieldSubCandidates.map((p) => p.number), contains(10));
    // The goalie is still reachable for deliberate keeper rotation.
    expect(g.goalieOnField?.number, 7);
  });

  test('a late arrival can be added mid-game and starts on the bench', () {
    final g = freshGame();
    for (var i = 0; i < 20; i++) {
      g.tick();
    }
    g.addPlayer('Late', number: 99);
    final p99 = g.roster.firstWhere((p) => p.number == 99);
    expect(p99.onField, false);
    expect(p99.secondsPlayed, 0);
    expect(g.fieldCount, 2); // unaffected until subbed on
  });

  test('an injured player can be removed mid-game, even from the field', () {
    final g = freshGame();
    for (var i = 0; i < 20; i++) {
      g.tick();
    }
    g.removePlayer(idOf(g, 7)); // 7 was on the field
    expect(g.roster.any((p) => p.number == 7), false);
    expect(g.fieldCount, 1); // 10 remains; 7 is gone, not just benched
  });

  test('ending the game freezes the clock and stops sub alerts', () {
    final g = freshGame();
    g.subIntervalSeconds = 5;
    var alerts = 0;
    g.onSubDue = () => alerts++;
    g.endGame();
    expect(g.clockRunning, false);
    expect(g.gameEnded, true);
    for (var i = 0; i < 20; i++) {
      g.tick();
    }
    expect(g.gameSeconds, 0); // clock never advanced
    expect(alerts, 0); // no more sub reminders once the game is over
  });

  test('starting a new game after ending clears gameEnded', () {
    final g = freshGame();
    g.endGame();
    g.newGame();
    expect(g.gameEnded, false);
    expect(g.gameStarted, false);
  });

  test('players need a name; number is optional and unique', () {
    final g = freshGame();
    g.addPlayer('   '); // blank name rejected
    g.addPlayer('Dup', number: 7); // duplicate number rejected
    expect(g.roster.length, 3);
    g.addPlayer('Numberless');
    final p = g.roster.firstWhere((p) => p.name == 'Numberless');
    expect(p.number, null);
    expect(p.badgeText, 'N');
    g.addPlayer('Other'); // two numberless players coexist
    expect(g.roster.length, 5);
    g.editPlayer(p.id, 'Nums', 42);
    expect(p.displayName, 'Nums');
    expect(p.number, 42);
    g.editPlayer(p.id, '  ', null); // blank name ignored
    expect(p.displayName, 'Nums');
  });

  test('old saves keyed by number still load', () {
    final g = GameState();
    g.loadFromJson({
      'roster': [
        {'number': 5},
        {'number': 8, 'name': 'Sam'},
      ]
    });
    expect(g.roster.map((p) => p.name), ['#5', 'Sam']);
    expect(g.roster.map((p) => p.id), [5, 8]);
  });

  test('marking a player absent benches them and blocks re-selection', () {
    final g = freshGame();
    g.setPresent(idOf(g, 7), false); // 7 was a starter
    final p7 = g.roster.firstWhere((p) => p.number == 7);
    expect(p7.onField, false);
    expect(g.fieldCount, 1);
    // Absent players are excluded from sub candidates and the live roster.
    expect(g.benchSortedByLeastPlayed.any((p) => p.number == 7), false);
    expect(g.rosterByLeastPlayed.any((p) => p.number == 7), false);
    // Tapping an absent player to start them is a no-op.
    g.toggleStarter(idOf(g, 7));
    expect(p7.onField, false);
  });

  test('newGame resets everyone to present for the next game', () {
    final g = freshGame();
    g.setPresent(idOf(g, 7), false);
    g.newGame();
    expect(g.roster.firstWhere((p) => p.number == 7).isPresent, true);
  });

  test('a player can come on without anyone going off; target grows', () {
    final g = freshGame();
    g.applySwap([idOf(g, 3)], []);
    expect(g.fieldCount, 3);
    expect(g.onFieldTarget, 3);
  });

  test('goals can be added and undone', () {
    final g = freshGame();
    g.addGoal(idOf(g, 7));
    g.addGoal(idOf(g, 7));
    g.addGoal(idOf(g, 10));
    expect(g.roster.firstWhere((p) => p.number == 7).goals, 2);
    expect(g.roster.firstWhere((p) => p.number == 10).goals, 1);
    g.undoGoal(idOf(g, 7));
    expect(g.roster.firstWhere((p) => p.number == 7).goals, 1);
    // Undoing past zero is a no-op, not negative.
    g.undoGoal(idOf(g, 10));
    g.undoGoal(idOf(g, 10));
    expect(g.roster.firstWhere((p) => p.number == 10).goals, 0);
  });

  test('goals reset when a game (re)starts', () {
    final g = freshGame();
    g.addGoal(idOf(g, 7));
    expect(g.roster.firstWhere((p) => p.number == 7).goals, 1);
    g.startGame();
    expect(g.roster.firstWhere((p) => p.number == 7).goals, 0);
  });
}
