import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences (not calculator state): feedback and appearance.
class AppSettings extends ChangeNotifier {
  AppSettings({
    this.vibration = true,
    this.keySound = false,
    this.skinId = 'classic',
    this.modelId = 'plus',
  });

  static const _key = 'wcalc.app.v1';

  /// Short vibration on each key press.
  bool vibration;

  /// System click sound on each key press.
  bool keySound;

  /// Selected [CalcSkin] id.
  String skinId;

  /// Selected calculator model id (see CalcModel).
  String modelId;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      vibration = m['vibration'] != false;
      keySound = m['keySound'] == true;
      final skin = m['skin'];
      if (skin is String) skinId = skin;
      final model = m['model'];
      if (model is String) modelId = model;
      notifyListeners();
    } on Object {
      // Unreadable preferences: keep defaults.
    }
  }

  void update({
    bool? vibration,
    bool? keySound,
    String? skinId,
    String? modelId,
  }) {
    this.vibration = vibration ?? this.vibration;
    this.keySound = keySound ?? this.keySound;
    this.skinId = skinId ?? this.skinId;
    this.modelId = modelId ?? this.modelId;
    notifyListeners();
    _save();
  }

  /// Applies a skin without saving it (web `?skin=` links).
  void preview({required String skinId}) {
    this.skinId = skinId;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'vibration': vibration,
          'keySound': keySound,
          'skin': skinId,
        }),
      );
    } on Object {
      // Best effort.
    }
  }
}

/// Gives widgets access to [AppSettings] and rebuilds them when it changes.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}

/// Build-time version, passed by CI with --dart-define=APP_VERSION=…
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'development build',
);
