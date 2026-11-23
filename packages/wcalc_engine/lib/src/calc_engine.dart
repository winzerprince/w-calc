import 'calc_key.dart';

/// What the app needs from any calculator model's engine.
abstract interface class CalcEngine {
  void press(CalcKey key);

  /// Keys that may compute for a long time (the app shows a busy screen).
  bool isSlowKey(CalcKey key);

  /// CLR All: memories, data and setup back to defaults.
  void resetAll();

  Map<String, Object?> saveState();
  void restoreState(Map<String, Object?> state);

  /// The shown result as plain text for the clipboard, or null.
  String? get copyText;
}
