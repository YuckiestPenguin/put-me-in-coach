/// A single player on the roster, identified only by their shirt number
/// (the league uses numbers, not names, since the players are children).
class Player {
  final int number;

  /// Total seconds this player has spent on the field this game.
  int secondsPlayed;

  /// Whether the player is currently on the field.
  bool onField;

  Player({
    required this.number,
    this.secondsPlayed = 0,
    this.onField = false,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'secondsPlayed': secondsPlayed,
        'onField': onField,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        number: json['number'] as int,
        secondsPlayed: json['secondsPlayed'] as int? ?? 0,
        onField: json['onField'] as bool? ?? false,
      );
}
