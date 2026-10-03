/// A league's rules: how the game is structured and when subs are due. Saved in
/// Firestore under `users/{uid}/leagues/{id}`.
class League {
  /// Firestore doc id; null until the league has been saved.
  final String? id;
  String name;
  int periodCount;

  /// Minutes, in half-minute steps (e.g. 7.5).
  double periodMinutes;
  int playersOnField;
  double subIntervalMinutes;

  /// If set, the league allows one extra player on the field when a team is
  /// trailing by more than this many goals. Null means no such rule.
  int? extraPlayerTrailingBy;

  League({
    this.id,
    required this.name,
    this.periodCount = 2,
    this.periodMinutes = 25,
    this.playersOnField = 7,
    this.subIntervalMinutes = 5,
    this.extraPlayerTrailingBy,
  });

  /// Word for a period: Half, Third, Quarter, or a generic Period.
  static String periodLabelFor(int count) => switch (count) {
    2 => 'Half',
    3 => 'Third',
    4 => 'Quarter',
    _ => 'Period',
  };

  String get periodLabel => periodLabelFor(periodCount);

  double get totalMinutes => periodCount * periodMinutes;

  /// Minutes without a trailing ".0": 25 -> "25", 7.5 -> "7.5".
  static String fmtMinutes(double m) =>
      m == m.roundToDouble() ? m.toInt().toString() : m.toString();

  /// e.g. "2 halves × 25 min · 7 on field · sub every 5 min".
  String get summary {
    final label = periodLabel.toLowerCase();
    final parts = [
      '$periodCount $label${periodCount == 1 ? '' : 's'} × ${fmtMinutes(periodMinutes)} min',
      '$playersOnField on field',
      'sub every ${fmtMinutes(subIntervalMinutes)} min',
      if (extraPlayerTrailingBy != null)
        'extra player if down by more than $extraPlayerTrailingBy',
    ];
    return parts.join(' · ');
  }

  League copy() => League(
    id: id,
    name: name,
    periodCount: periodCount,
    periodMinutes: periodMinutes,
    playersOnField: playersOnField,
    subIntervalMinutes: subIntervalMinutes,
    extraPlayerTrailingBy: extraPlayerTrailingBy,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'periodCount': periodCount,
    'periodMinutes': periodMinutes,
    'playersOnField': playersOnField,
    'subIntervalMinutes': subIntervalMinutes,
    'extraPlayerTrailingBy': extraPlayerTrailingBy,
  };

  factory League.fromJson(String id, Map<String, dynamic> json) => League(
    id: id,
    name: json['name'] as String? ?? 'League',
    periodCount: json['periodCount'] as int? ?? 2,
    periodMinutes: (json['periodMinutes'] as num?)?.toDouble() ?? 25,
    playersOnField: json['playersOnField'] as int? ?? 7,
    subIntervalMinutes: (json['subIntervalMinutes'] as num?)?.toDouble() ?? 5,
    extraPlayerTrailingBy: json['extraPlayerTrailingBy'] as int?,
  );
}
