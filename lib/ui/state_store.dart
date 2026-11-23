import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Keeps memories, Ans and setup across app restarts (the real units keep
/// them while switched off). Web: browser localStorage. Each engine family
/// has its own snapshot.
class StateStore {
  /// Two-line models (key kept from the first release).
  static const twoLineKey = 'wcalc.state.v1';
  static const textbookKey = 'wcalc.textbook.v1';

  /// The saved state, or null when there is none or storage is unavailable.
  static Future<Map<String, Object?>?> read([String key = twoLineKey]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      // Storage unavailable (private mode, blocked): start fresh.
      return null;
    }
  }

  static Future<void> save(CalcEngine calc, [String key = twoLineKey]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(calc.saveState()));
    } on Object {
      // Ignore: persistence is best-effort.
    }
  }
}
