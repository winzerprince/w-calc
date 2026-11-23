import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished calculation.
@immutable
class HistoryItem {
  const HistoryItem(this.time, this.input, this.result);

  final DateTime time;
  final String input;
  final String result;

  Map<String, Object> toJson() => {
    't': time.millisecondsSinceEpoch,
    'i': input,
    'r': result,
  };

  static HistoryItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'], i = j['i'], r = j['r'];
    if (t is! int || i is! String || r is! String) return null;
    return HistoryItem(DateTime.fromMillisecondsSinceEpoch(t), i, r);
  }
}

/// Calculation history kept per calculator model; saved on the device
/// while [persist] is on.
class HistoryStore extends ChangeNotifier {
  HistoryStore._();

  static final instance = HistoryStore._();

  static const _key = 'wcalc.history.v1';

  /// Newest last, at most [perModel] per model.
  static const perModel = 300;

  final Map<String, List<HistoryItem>> _items = {};
  bool persist = true;

  List<HistoryItem> of(String modelId) =>
      List.unmodifiable(_items[modelId] ?? const []);

  /// Models with history, in no particular order.
  Iterable<String> get models =>
      _items.keys.where((k) => _items[k]!.isNotEmpty);

  Future<void> load({required bool persist}) async {
    this.persist = persist;
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      for (final MapEntry(:key, :value) in m.entries) {
        if (key is! String || value is! List) continue;
        _items[key] = [for (final j in value) ?HistoryItem.fromJson(j)];
      }
      notifyListeners();
    } on Object {
      // Unreadable: start empty.
    }
  }

  void add(String modelId, String input, String result, {DateTime? at}) {
    final list = _items.putIfAbsent(modelId, () => []);
    list.add(HistoryItem(at ?? DateTime.now(), input, result));
    if (list.length > perModel) list.removeRange(0, list.length - perModel);
    notifyListeners();
    _save();
  }

  void clear(String modelId) {
    _items.remove(modelId);
    notifyListeners();
    _save();
  }

  /// Switching saving off removes what is stored on the device (the list
  /// stays visible until the app closes).
  Future<void> setPersist(bool on) async {
    persist = on;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (on) {
        await _write(prefs);
      } else {
        await prefs.remove(_key);
      }
    } on Object {
      // Best effort.
    }
  }

  Future<void> _save() async {
    if (!persist) return;
    try {
      await _write(await SharedPreferences.getInstance());
    } on Object {
      // Best effort.
    }
  }

  Future<void> _write(SharedPreferences prefs) => prefs.setString(
    _key,
    jsonEncode({
      for (final e in _items.entries)
        e.key: [for (final i in e.value) i.toJson()],
    }),
  );

  @visibleForTesting
  void resetForTest() {
    _items.clear();
    persist = true;
  }
}
