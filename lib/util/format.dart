/// Format a number of seconds as `m:ss` (e.g. 75 -> "1:15").
String mmss(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
