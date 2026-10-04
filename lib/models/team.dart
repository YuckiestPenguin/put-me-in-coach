import 'player.dart';

/// A team: a name (the only required field), an optional league, and a roster.
/// Saved in Firestore under `users/{uid}/teams/{id}`.
class Team {
  /// Firestore doc id; null until the team has been saved.
  final String? id;
  String name;

  /// Id of the league this team plays in, if any.
  String? leagueId;
  final List<Player> players;

  Team({this.id, required this.name, this.leagueId, List<Player>? players})
      : players = players ?? [];

  /// Next unused player id within this team.
  int nextPlayerId() =>
      players.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;

  bool numberTaken(int number, {int? exceptId}) =>
      players.any((p) => p.number == number && p.id != exceptId);

  void sortPlayers() => players
      .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Give [role] to [playerId] only (roles have a single holder); passing a
  /// player who already holds it turns it off.
  void toggleRole(int playerId, PlayerRole role) {
    final target = players.firstWhere((p) => p.id == playerId);
    final turningOn = !target.hasRole(role);
    for (final p in players) {
      p.setRole(role, false);
    }
    target.setRole(role, turningOn);
  }

  Team copy() => Team(
        id: id,
        name: name,
        leagueId: leagueId,
        players: [for (final p in players) Player.fromJson(p.toTeamJson())],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'leagueId': leagueId,
        'players': [for (final p in players) p.toTeamJson()],
      };

  factory Team.fromJson(String id, Map<String, dynamic> json) => Team(
        id: id,
        name: json['name'] as String? ?? 'Team',
        leagueId: json['leagueId'] as String?,
        players: [
          for (final p in (json['players'] as List? ?? []))
            Player.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );
}
