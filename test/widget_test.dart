import 'package:flutter_test/flutter_test.dart';
import 'package:put_me_in_coach/models/game_state.dart';
import 'package:put_me_in_coach/models/player.dart';

void main() {
  GameState freshGame() {
    final g = GameState();
    g.onFieldTarget = 2;
    g.addPlayer(7);
    g.addPlayer(10);
    g.addPlayer(3);
    g.toggleStarter(7); // 7 and 10 start on the field
    g.toggleStarter(10);
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
    g.applySwap([3], [7]); // bring on 3, take off 7
    expect(g.roster.firstWhere((p) => p.number == 3).onField, true);
    expect(g.roster.firstWhere((p) => p.number == 7).onField, false);
    expect(g.secondsUntilNextSub, 300); // counter reset on swap
    expect(g.fieldCount, 2); // still two on the field
  });

  test('a role is single-assignment — moving it clears the previous holder', () {
    final g = freshGame();
    g.toggleRole(7, PlayerRole.goalie);
    expect(g.roster.firstWhere((p) => p.number == 7).isGoalie, true);

    // Assigning goalie to 10 must take it away from 7.
    g.toggleRole(10, PlayerRole.goalie);
    expect(g.roster.firstWhere((p) => p.number == 7).isGoalie, false);
    expect(g.roster.firstWhere((p) => p.number == 10).isGoalie, true);
    expect(g.roster.where((p) => p.isGoalie).length, 1);

    // Tapping the same player again clears the role entirely.
    g.toggleRole(10, PlayerRole.goalie);
    expect(g.roster.where((p) => p.isGoalie).length, 0);

    // Roles are independent: captain and favorite can coexist on a player.
    g.toggleRole(3, PlayerRole.captain);
    g.toggleRole(3, PlayerRole.favorite);
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
    expect(g.fieldSortedByMostPlayed.first.secondsPlayed, 30);
  });
}
