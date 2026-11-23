import 'package:flutter/widgets.dart';

import 'keypad_layout.dart';
import 'lcd/lcd_painter.dart';

/// Visual theme of the calculator body, keys, legends and LCD.
///
/// Skins only change colours; layout and behaviour come from the calculator
/// model. Future calculator models add their own skins.
class CalcSkin {
  const CalcSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.background,
    required this.bodyTop,
    required this.body,
    required this.bezel,
    required this.brandText,
    required this.modifierKey,
    required this.modifierText,
    required this.functionKey,
    required this.functionText,
    required this.digitKey,
    required this.digitText,
    required this.operatorKey,
    required this.clearKey,
    required this.clearText,
    required this.disc,
    required this.discMark,
    required this.labels,
    required this.lcd,
    this.solarStrip = const Color(0xFF3A2A22),
  });

  final String id;
  final String name;
  final String description;
  final Color background;
  final Color bodyTop;
  final Color body;
  final Color bezel;
  final Color brandText;
  final Color modifierKey;
  final Color modifierText;
  final Color functionKey;
  final Color functionText;
  final Color digitKey;
  final Color digitText;
  final Color operatorKey;
  final Color clearKey;
  final Color clearText;
  final Color disc;
  final Color discMark;
  final Map<LabelKind, Color> labels;
  final LcdPalette lcd;
  final Color solarStrip;

  Color label(LabelKind kind) => labels[kind]!;

  static const classic = CalcSkin(
    id: 'classic',
    name: 'Classic',
    description: 'Navy body, grey keys, green-grey LCD',
    background: Color(0xFF15171C),
    bodyTop: Color(0xFF353A4A),
    body: Color(0xFF262A36),
    bezel: Color(0xFF1B1E26),
    brandText: Color(0xFFFFFFFF),
    modifierKey: Color(0xFFD9D6CF),
    modifierText: Color(0xFF22252C),
    functionKey: Color(0xFF1A1C22),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFF9DA2AA),
    digitText: Color(0xFFFFFFFF),
    operatorKey: Color(0xFF8E939C),
    clearKey: Color(0xFFB4505A),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFFD9D6CF),
    discMark: Color(0xFF8A877F),
    labels: {
      LabelKind.shift: Color(0xFFF2A33A),
      LabelKind.alpha: Color(0xFFE5506A),
      LabelKind.complex: Color(0xFFB98AE8),
      LabelKind.stat: Color(0xFF6FA8F0),
      LabelKind.base: Color(0xFF5CC77A),
      LabelKind.plain: Color(0xFFB9BDC6),
      LabelKind.neutral: Color(0xFF8D93A0),
    },
    lcd: LcdPalette.classic,
  );

  static const midnight = CalcSkin(
    id: 'midnight',
    name: 'Midnight',
    description: 'Dark keys and a backlit LCD for night study',
    background: Color(0xFF050608),
    bodyTop: Color(0xFF1B1D22),
    body: Color(0xFF111215),
    bezel: Color(0xFF08090B),
    brandText: Color(0xFFE6E6E6),
    modifierKey: Color(0xFF3A3D45),
    modifierText: Color(0xFFE6E6E6),
    functionKey: Color(0xFF22252B),
    functionText: Color(0xFFE6E6E6),
    digitKey: Color(0xFF34373F),
    digitText: Color(0xFFFFFFFF),
    operatorKey: Color(0xFF2C2F36),
    clearKey: Color(0xFF8E3A44),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF3A3D45),
    discMark: Color(0xFFB0B3BA),
    labels: {
      LabelKind.shift: Color(0xFFFFB347),
      LabelKind.alpha: Color(0xFFFF6B81),
      LabelKind.complex: Color(0xFFC9A3FF),
      LabelKind.stat: Color(0xFF85B8FF),
      LabelKind.base: Color(0xFF6EDB8F),
      LabelKind.plain: Color(0xFFC4C7CE),
      LabelKind.neutral: Color(0xFF9DA2AD),
    },
    lcd: LcdPalette(glass: Color(0xFF16261C), ink: Color(0xFF9CF2B4)),
    solarStrip: Color(0xFF1E1714),
  );

  static const highContrast = CalcSkin(
    id: 'high-contrast',
    name: 'High contrast',
    description: 'Black and white with bold legends for low vision',
    background: Color(0xFF000000),
    bodyTop: Color(0xFF000000),
    body: Color(0xFF000000),
    bezel: Color(0xFF000000),
    brandText: Color(0xFFFFFFFF),
    modifierKey: Color(0xFFFFFFFF),
    modifierText: Color(0xFF000000),
    functionKey: Color(0xFF000000),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFFFFFFFF),
    digitText: Color(0xFF000000),
    operatorKey: Color(0xFFFFE14D),
    clearKey: Color(0xFFFF5C5C),
    clearText: Color(0xFF000000),
    disc: Color(0xFFFFFFFF),
    discMark: Color(0xFF000000),
    labels: {
      LabelKind.shift: Color(0xFFFFE14D),
      LabelKind.alpha: Color(0xFFFF8A8A),
      LabelKind.complex: Color(0xFFE0B8FF),
      LabelKind.stat: Color(0xFF9CCBFF),
      LabelKind.base: Color(0xFF8CFF9E),
      LabelKind.plain: Color(0xFFFFFFFF),
      LabelKind.neutral: Color(0xFFDDDDDD),
    },
    lcd: LcdPalette(glass: Color(0xFFFFFFFF), ink: Color(0xFF000000)),
    solarStrip: Color(0xFF222222),
  );

  static const ivory = CalcSkin(
    id: 'ivory',
    name: 'Ivory',
    description: 'Light body with dark keys',
    background: Color(0xFFE4E1DA),
    bodyTop: Color(0xFFF4F1EA),
    body: Color(0xFFE2DED4),
    bezel: Color(0xFF3B3E46),
    brandText: Color(0xFF2B2E36),
    modifierKey: Color(0xFF5E636E),
    modifierText: Color(0xFFFFFFFF),
    functionKey: Color(0xFF2E323B),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFFFFFFFF),
    digitText: Color(0xFF2B2E36),
    operatorKey: Color(0xFFD6D2C8),
    clearKey: Color(0xFFC9535E),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF5E636E),
    discMark: Color(0xFFE2DED4),
    labels: {
      LabelKind.shift: Color(0xFFC56A00),
      LabelKind.alpha: Color(0xFFC21F3A),
      LabelKind.complex: Color(0xFF7A3FB8),
      LabelKind.stat: Color(0xFF1F5FB8),
      LabelKind.base: Color(0xFF1E7F3B),
      LabelKind.plain: Color(0xFF4A4E57),
      LabelKind.neutral: Color(0xFF6B6F78),
    },
    lcd: LcdPalette.classic,
    solarStrip: Color(0xFF5A463B),
  );

  static const all = [classic, midnight, highContrast, ivory];

  static CalcSkin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => classic);

  /// The skin in effect for [context].
  static CalcSkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin ?? classic;
}

/// Provides the active [CalcSkin] to the widget tree.
class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final CalcSkin skin;

  @override
  bool updateShouldNotify(SkinScope oldWidget) => oldWidget.skin != skin;
}
