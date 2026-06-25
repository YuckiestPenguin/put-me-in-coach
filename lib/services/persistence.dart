import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// Saves/restores the whole game to local storage so closing and reopening the
/// app mid-game picks up exactly where the coach left off.
class Persistence {
  static const _key = 'game_state_v1';

  static Future<void> save(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Loads any saved game into [state]. Returns true if something was restored.
  static Future<bool> load(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return false;
    try {
      state.loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
