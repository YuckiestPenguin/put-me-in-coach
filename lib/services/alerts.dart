import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Sound + vibration for the "sub is due" alert, plus keeping the screen awake
/// during a game. All calls are guarded so they no-op safely on platforms that
/// don't support them (e.g. desktop/web during development).
class Alerts {
  static final AudioPlayer _player = AudioPlayer();

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Fire the attention alert: chime + a buzz pattern.
  static Future<void> subDue() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/whistle.wav'));
    } catch (_) {/* audio unavailable — ignore */}

    try {
      if (_isMobile && await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 300, 150, 300, 150, 500]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {/* haptics unavailable — ignore */}
  }

  /// Light tap feedback for ordinary taps (e.g. confirming a swap).
  static void tap() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> keepAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {/* unsupported — ignore */}
  }
}
