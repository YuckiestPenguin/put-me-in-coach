import 'package:flutter_test/flutter_test.dart';
import 'package:put_me_in_coach/models/game_state.dart';
import 'package:put_me_in_coach/models/league.dart';
import 'package:put_me_in_coach/models/team.dart';
import 'package:put_me_in_coach/util/format.dart';
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

  test(
    'a role is single-assignment — moving it clears the previous holder',
    () {
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
    },
  );

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
      ],
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

  test('game records start and end times and survives a reload', () {
    final g = freshGame();
    expect(g.startedAt, isNotNull);
    expect(g.endedAt, null);
    g.endGame();
    expect(g.endedAt, isNotNull);
    final g2 = GameState()..loadFromJson(g.toJson());
    expect(g2.startedAt, g.startedAt);
    expect(g2.endedAt, g.endedAt);
    g.newGame();
    expect(g.startedAt, null);
  });

  test('the end-of-game hook fires once with a full summary', () {
    final g = freshGame();
    Map<String, dynamic>? summary;
    var calls = 0;
    g.onGameEnded = (s) {
      summary = s;
      calls++;
    };
    g.tick();
    expect(calls, 0); // ticks never reach the cloud
    g.endGame();
    expect(calls, 1);
    expect(summary!['players'], hasLength(3));
    expect(summary!['gameSeconds'], 1);
  });

  test('picking a team loads a fresh roster; clearing it empties it', () {
    final g = freshGame();
    final team = Team(id: 't1', name: 'Tigers', leagueId: 'L1');
    team.players.add(Player(id: 1, name: 'Zed', number: 9, isGoalie: true));
    team.players.add(Player(id: 2, name: 'Amy'));
    g.applyTeam(team);
    expect(g.roster.map((p) => p.name), ['Amy', 'Zed']); // replaced, sorted
    expect(g.teamId, 't1');
    expect(g.teamName, 'Tigers');
    expect(g.roster.last.isGoalie, true);
    expect(g.roster.every((p) => p.secondsPlayed == 0 && p.isPresent), true);
    // Game-only edits don't touch the team.
    g.addPlayer('Guest');
    g.roster.firstWhere((p) => p.name == 'Zed').goals = 3;
    expect(team.players.length, 2);
    expect(team.players.first.toTeamJson().containsKey('goals'), false);
    g.clearTeam();
    expect(g.roster, isEmpty);
    expect(g.teamId, null);
  });

  test('picking a league applies its rules; clearing keeps the numbers', () {
    final g = GameState();
    g.applyLeague(
      League(
        id: 'L1',
        name: 'Rec U10',
        periodCount: 4,
        periodMinutes: 12.5,
        playersOnField: 9,
        subIntervalMinutes: 6.5,
        extraPlayerTrailingBy: 4,
      ),
    );
    expect(g.periodCount, 4);
    expect(g.periodMinutes, 12.5);
    expect(g.onFieldTarget, 9);
    expect(g.subIntervalSeconds, 390);
    expect(g.extraPlayerTrailingBy, 4);
    expect(g.leagueName, 'Rec U10');
    g.clearLeague();
    expect(g.leagueId, null);
    expect(g.extraPlayerTrailingBy, null);
    expect(
      g.periodCount,
      4,
    ); // custom rules start from where the league left off
  });

  test('team and league are recorded on the summary and survive a reload', () {
    final g = freshGame();
    g.applyTeam(
      Team(id: 't1', name: 'Tigers')..players.add(Player(id: 1, name: 'Amy')),
    );
    g.applyLeague(League(id: 'L1', name: 'Rec U10'));
    g.toggleStarter(1);
    g.startGame();
    final s = g.summaryJson();
    expect(s['teamId'], 't1');
    expect(s['teamName'], 'Tigers');
    expect(s['leagueName'], 'Rec U10');
    final g2 = GameState()..loadFromJson(g.toJson());
    expect(g2.teamName, 'Tigers');
    expect(g2.leagueId, 'L1');
  });

  test('a one-off game has no team or league on its summary', () {
    final s = freshGame().summaryJson();
    expect(s['teamId'], null);
    expect(s['leagueName'], null);
  });

  test('setup flow: home -> setup -> game; new game returns to setup', () {
    final g = GameState();
    expect(g.settingUp, false);
    g.beginSetup();
    expect(g.settingUp, true);
    g.cancelSetup();
    expect(g.settingUp, false);
    final g2 = freshGame();
    expect(g2.settingUp, false);
    g2.newGame();
    expect(g2.settingUp, true);
  });

  test(
    'starting setup from home clears any previous team, league and roster',
    () {
      final g = freshGame();
      g.applyTeam(
        Team(id: 't1', name: 'Tigers')..players.add(Player(id: 1, name: 'Amy')),
      );
      g.applyLeague(
        League(id: 'L1', name: 'Rec U10', extraPlayerTrailingBy: 4),
      );
      g.goHome();
      g.beginSetup();
      expect(g.roster, isEmpty);
      expect(g.teamId, null);
      expect(g.leagueId, null);
      expect(g.extraPlayerTrailingBy, null);
    },
  );

  test('goHome leaves the game and lands on home, not setup', () {
    final g = freshGame();
    g.goHome();
    expect(g.gameStarted, false);
    expect(g.settingUp, false);
    expect(g.roster.length, 3); // roster kept
  });

  test('a different user signing in does not inherit the previous roster', () {
    final g = freshGame();
    g.adoptUser('coachA'); // legacy local data is adopted, not wiped
    expect(g.roster.length, 3);
    expect(g.ownerUid, 'coachA');
    g.adoptUser('coachA'); // same user again: untouched
    expect(g.roster.length, 3);
    g.adoptUser('coachB');
    expect(g.roster, isEmpty);
    expect(g.gameStarted, false);
    expect(g.ownerUid, 'coachB');
    // The owner survives a reload so the check works across app restarts.
    final g2 = GameState()..loadFromJson(g.toJson());
    expect(g2.ownerUid, 'coachB');
  });

  test('league round-trips through json and describes itself', () {
    final l = League(
      name: 'Rec U10',
      periodCount: 4,
      periodMinutes: 12.5,
      playersOnField: 7,
      subIntervalMinutes: 6.5,
      extraPlayerTrailingBy: 4,
    );
    final back = League.fromJson('abc', l.toJson());
    expect(back.id, 'abc');
    expect(back.name, 'Rec U10');
    expect(back.periodCount, 4);
    expect(back.extraPlayerTrailingBy, 4);
    expect(back.totalMinutes, 50);
    expect(back.periodMinutes, 12.5);
    expect(
      back.summary,
      '4 quarters × 12.5 min · 7 on field · sub every 6.5 min · extra player if down by more than 4',
    );
    // Missing fields fall back to sensible defaults.
    // Older docs stored whole minutes as ints.
    expect(League.fromJson('o', {'periodMinutes': 20}).periodMinutes, 20.0);
    final bare = League.fromJson('x', {});
    expect(bare.periodCount, 2);
    expect(bare.extraPlayerTrailingBy, null);
  });

  test('period length and sub interval can be set in half minutes', () {
    final g = GameState();
    g.setPeriodMinutes(7.5);
    expect(g.periodLengthSeconds, 450);
    g.setPeriodMinutes(0.25); // below the half-minute floor: ignored
    expect(g.periodMinutes, 7.5);
    g.setSubIntervalMinutes(4.5);
    expect(g.subIntervalSeconds, 270);
    expect(g.subIntervalMinutes, 4.5);
    // Old saves stored whole minutes as ints.
    final g2 = GameState()..loadFromJson({'periodMinutes': 20});
    expect(g2.periodMinutes, 20.0);
    expect(minutesText(7.5), '7.5');
    expect(minutesText(25), '25');
  });

  test('team needs only a name; roster and league are optional', () {
    final t = Team(name: 'Tigers');
    expect(t.leagueId, null);
    expect(t.players, isEmpty);
    final back = Team.fromJson('t1', t.toJson());
    expect(back.name, 'Tigers');
    expect(back.players, isEmpty);
    expect(Team.fromJson('t2', {}).name, 'Team'); // defensive default
  });

  test('team roster round-trips with roles, ids and unique numbers', () {
    final t = Team(name: 'Tigers', leagueId: 'L1');
    t.players.add(Player(id: t.nextPlayerId(), name: 'Zed', number: 9));
    t.players.add(Player(id: t.nextPlayerId(), name: 'Amy'));
    t.sortPlayers();
    expect(t.players.map((p) => p.name), ['Amy', 'Zed']);
    expect(t.numberTaken(9), true);
    expect(t.numberTaken(9, exceptId: 1), false); // editing Zed himself
    expect(t.numberTaken(4), false);
    final amy = t.players.first.id;
    final zed = t.players.last.id;
    t.toggleRole(amy, PlayerRole.goalie);
    t.toggleRole(zed, PlayerRole.goalie); // moves the single goalie role
    final back = Team.fromJson('t1', t.toJson());
    expect(back.leagueId, 'L1');
    expect(back.players.firstWhere((p) => p.id == zed).isGoalie, true);
    expect(back.players.firstWhere((p) => p.id == amy).isGoalie, false);
    // Per-game state is never saved with a team.
    expect(t.players.first.toTeamJson().containsKey('secondsPlayed'), false);
    // Editing a copy doesn't touch the original.
    final c = t.copy()..players.first.name = 'Changed';
    expect(t.players.first.name, 'Amy');
    expect(c.players.first.name, 'Changed');
  });

  test('score = player goals + unattributed; they have their own counter', () {
    final g = freshGame();
    g.addGoal(idOf(g, 7));
    g.addGoal(idOf(g, 10));
    g.addUnattributedGoal();
    g.addTheirGoal();
    g.addTheirGoal();
    expect(g.ourScore, 3);
    expect(g.theirScore, 2);
    g.undoGoal(idOf(g, 7)); // undoing a player's goal lowers our score
    expect(g.ourScore, 2);
    g.undoUnattributedGoal();
    g.undoUnattributedGoal(); // can't go below zero
    expect(g.unattributedGoals, 0);
    g.undoTheirGoal();
    g.undoTheirGoal();
    g.undoTheirGoal();
    expect(g.theirScore, 0);
  });

  test('removing a player keeps their goals in the score', () {
    final g = freshGame();
    g.addGoal(idOf(g, 7));
    g.addGoal(idOf(g, 7));
    expect(g.ourScore, 2);
    g.removePlayer(idOf(g, 7)); // e.g. injured
    expect(g.ourScore, 2);
  });

  test('extra player allowed only when trailing by more than the threshold', () {
    final g = freshGame();
    g.applyLeague(League(name: 'L', extraPlayerTrailingBy: 4));
    for (var i = 0; i < 4; i++) {
      g.addTheirGoal();
    }
    expect(g.trailingBy, 4);
    expect(g.extraPlayerAllowed, false); // 4 is not "more than 4"
    g.addTheirGoal();
    expect(g.extraPlayerAllowed, true);
    g.addGoal(idOf(g, 7)); // back to 4 down
    expect(g.extraPlayerAllowed, false);
    g.endGame();
    g.addTheirGoal();
    g.addTheirGoal();
    expect(g.extraPlayerAllowed, false); // never after the game ends
    // A league with no such rule never allows it.
    final h = freshGame();
    for (var i = 0; i < 9; i++) {
      h.addTheirGoal();
    }
    expect(h.extraPlayerAllowed, false);
  });

  test('score is saved, reset for a new game, and shown in the summary', () {
    final g = freshGame();
    g.addGoal(idOf(g, 7));
    g.addTheirGoal();
    final s = g.summaryJson();
    expect(s['ourScore'], 1);
    expect(s['theirScore'], 1);
    expect(resultText(s), '1–1 (Draw)');
    expect(resultText({'ourScore': 3, 'theirScore': 1}), '3–1 (Win)');
    expect(resultText({'ourScore': 0, 'theirScore': 2}), '0–2 (Loss)');
    expect(resultText({}), null); // games saved before scores existed
    final g2 = GameState()..loadFromJson(g.toJson());
    expect(g2.theirScore, 1);
    g.newGame();
    expect(g.theirScore, 0);
    expect(g.ourScore, 0);
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
