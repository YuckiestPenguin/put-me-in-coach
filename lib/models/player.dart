/// A role marker a player can carry. Each role is held by at most one player.
enum PlayerRole { goalie, captain, favorite }

/// A single player on the team roster. [name] is required and is what the UI
/// shows; the jersey [number] is optional (not every team uses them). [id] is
/// the permanent internal key every lookup in the app uses, so players stay
/// distinguishable regardless of name or number.
class Player {
  final int id;

  /// Display name.
  String name;

  /// Optional jersey number.
  int? number;

  /// Total seconds this player has spent on the field this game.
  int secondsPlayed;

  /// Whether the player is currently on the field.
  bool onField;

  /// Whether the player showed up for the current game. Absent players are
  /// grayed out and can't be selected as a starter or subbed on — this is
  /// per-game and resets to true (everyone assumed present) at [newGame].
  bool isPresent;

  /// Goals scored this game.
  int goals;

  /// Markers shown next to the name: 🧤 goalie, ⭐ favorite, C captain.
  bool isGoalie;
  bool isFavorite;
  bool isCaptain;

  Player({
    required this.id,
    required this.name,
    this.number,
    this.secondsPlayed = 0,
    this.onField = false,
    this.isPresent = true,
    this.goals = 0,
    this.isGoalie = false,
    this.isFavorite = false,
    this.isCaptain = false,
  });

  /// What to show in the UI.
  String get displayName => name;

  /// Short text for avatars: the jersey number if there is one, else the
  /// name's first letter.
  String get badgeText =>
      number?.toString() ?? (name.isEmpty ? '?' : name[0].toUpperCase());

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
        'id': id,
        'number': number,
        'name': name,
        'secondsPlayed': secondsPlayed,
        'onField': onField,
        'isPresent': isPresent,
        'goals': goals,
        'isGoalie': isGoalie,
        'isFavorite': isFavorite,
        'isCaptain': isCaptain,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        // Older saves keyed players by number and had optional names.
        id: json['id'] as int? ?? json['number'] as int,
        number: json['number'] as int?,
        name: (json['name'] as String?) ?? '#${json['number']}',
        secondsPlayed: json['secondsPlayed'] as int? ?? 0,
        onField: json['onField'] as bool? ?? false,
        isPresent: json['isPresent'] as bool? ?? true,
        goals: json['goals'] as int? ?? 0,
        isGoalie: json['isGoalie'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        isCaptain: json['isCaptain'] as bool? ?? false,
      );
}
