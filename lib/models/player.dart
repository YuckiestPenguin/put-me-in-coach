/// A role marker a player can carry. Each role is held by at most one player.
enum PlayerRole { goalie, captain, favorite }

/// A single player on the roster, identified only by their shirt number
/// (the league uses numbers, not names, since the players are children).
class Player {
  final int number;

  /// Total seconds this player has spent on the field this game.
  int secondsPlayed;

  /// Whether the player is currently on the field.
  bool onField;

  /// Markers shown next to the number: 🧤 goalie, ⭐ favorite, C captain.
  bool isGoalie;
  bool isFavorite;
  bool isCaptain;

  Player({
    required this.number,
    this.secondsPlayed = 0,
    this.onField = false,
    this.isGoalie = false,
    this.isFavorite = false,
    this.isCaptain = false,
  });

  bool hasRole(PlayerRole role) => switch (role) {
        PlayerRole.goalie => isGoalie,
        PlayerRole.captain => isCaptain,
        PlayerRole.favorite => isFavorite,
      };

  void setRole(PlayerRole role, bool value) {
    switch (role) {
      case PlayerRole.goalie:
        isGoalie = value;
      case PlayerRole.captain:
        isCaptain = value;
      case PlayerRole.favorite:
        isFavorite = value;
    }
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'secondsPlayed': secondsPlayed,
        'onField': onField,
        'isGoalie': isGoalie,
        'isFavorite': isFavorite,
        'isCaptain': isCaptain,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        number: json['number'] as int,
        secondsPlayed: json['secondsPlayed'] as int? ?? 0,
        onField: json['onField'] as bool? ?? false,
        isGoalie: json['isGoalie'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        isCaptain: json['isCaptain'] as bool? ?? false,
      );
}
