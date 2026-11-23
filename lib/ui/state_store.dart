import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Keeps memories, Ans and setup across app restarts (the real unit keeps
/// them while switched off). Web: browser localStorage.
class StateStore {
  static const _key = 'wcalc.state.v1';

  /// The saved state, or null when there is none or storage is unavailable.
  static Future<Map<String, Object?>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      // Storage unavailable (private mode, blocked): start fresh.
      return null;
    }
  }

  static Future<void> save(Calculator calc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(calc.saveState()));
    } on Object {
      // Ignore: persistence is best-effort.
    }
  }
}
