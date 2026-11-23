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

  /// Silver textbook body: blue-grey modifier keys, black function keys,
  /// white digits, orange DEL / AC, grey-green LCD.
  static const silver = CalcSkin(
    id: 'silver',
    name: 'Silver',
    description: 'Silver body, white digit keys, orange DEL / AC',
    background: Color(0xFF1B2230),
    bodyTop: Color(0xFFE3E6EA),
    body: Color(0xFFBCC2CA),
    bezel: Color(0xFF39445A),
    brandText: Color(0xFF233049),
    modifierKey: Color(0xFF8193BA),
    modifierText: Color(0xFF141B2B),
    functionKey: Color(0xFF26292F),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFFF7F7F4),
    digitText: Color(0xFF1C1F26),
    operatorKey: Color(0xFFF7F7F4),
    clearKey: Color(0xFFF0782C),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF8193BA),
    discMark: Color(0xFF3D4A66),
    labels: {
      LabelKind.shift: Color(0xFFC9700F),
      LabelKind.alpha: Color(0xFFC0304E),
      LabelKind.complex: Color(0xFF7A3FB8),
      LabelKind.stat: Color(0xFF1F5FB8),
      LabelKind.base: Color(0xFF1E7F3B),
      LabelKind.plain: Color(0xFF1D2433),
      LabelKind.neutral: Color(0xFF4A4E57),
    },
    lcd: LcdPalette(glass: Color(0xFFB8C3AE), ink: Color(0xFF1B2630)),
    solarStrip: Color(0xFF2E2420),
  );

  /// Black textbook body: grey digit keys, green DEL / AC, blue-green LCD.
  static const black = CalcSkin(
    id: 'black',
    name: 'Black',
    description: 'Black body, grey digit keys, green DEL / AC, blue LCD',
    background: Color(0xFF09090B),
    bodyTop: Color(0xFF2B2D31),
    body: Color(0xFF161719),
    bezel: Color(0xFF0D0E10),
    brandText: Color(0xFFE9E9E9),
    modifierKey: Color(0xFFA2A5AA),
    modifierText: Color(0xFF15161A),
    functionKey: Color(0xFF1E1F23),
    functionText: Color(0xFFF2F2F2),
    digitKey: Color(0xFF6D7177),
    digitText: Color(0xFFFFFFFF),
    operatorKey: Color(0xFF6D7177),
    clearKey: Color(0xFF7CC63C),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF8E9196),
    discMark: Color(0xFF2A2C30),
    labels: {
      LabelKind.shift: Color(0xFFE9C46A),
      LabelKind.alpha: Color(0xFFE6678A),
      LabelKind.complex: Color(0xFFC29BF0),
      LabelKind.stat: Color(0xFF7DB2F5),
      LabelKind.base: Color(0xFF66CF85),
      LabelKind.plain: Color(0xFFE9E9E9),
      LabelKind.neutral: Color(0xFFB5B8BD),
    },
    lcd: LcdPalette(glass: Color(0xFFA6CCCF), ink: Color(0xFF15232C)),
    solarStrip: Color(0xFF1A1512),
  );

  /// Slate: dark blue-grey body, blue 2nd key, light digit keys.
  static const slate = CalcSkin(
    id: 'slate',
    name: 'Slate',
    description: 'Dark slate body, blue 2nd key, light digit keys',
    background: Color(0xFF11151C),
    bodyTop: Color(0xFF3A4458),
    body: Color(0xFF252D3B),
    bezel: Color(0xFF151A23),
    brandText: Color(0xFFE6ECF5),
    modifierKey: Color(0xFF3C7BD8),
    modifierText: Color(0xFFFFFFFF),
    functionKey: Color(0xFF1B212C),
    functionText: Color(0xFFF2F4F8),
    digitKey: Color(0xFFE8EBF0),
    digitText: Color(0xFF1A1F29),
    operatorKey: Color(0xFFB8C1CF),
    clearKey: Color(0xFF3C7BD8),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF4A5568),
    discMark: Color(0xFFE6ECF5),
    labels: {
      LabelKind.shift: Color(0xFF7DB4FF),
      LabelKind.alpha: Color(0xFF8FE0A0),
      LabelKind.complex: Color(0xFFC9A3FF),
      LabelKind.stat: Color(0xFF7DB4FF),
      LabelKind.base: Color(0xFF8FE0A0),
      LabelKind.plain: Color(0xFFE6ECF5),
      LabelKind.neutral: Color(0xFFAAB4C3),
    },
    lcd: LcdPalette(glass: Color(0xFFC6D0C2), ink: Color(0xFF1A2420)),
    solarStrip: Color(0xFF241D1A),
  );

  /// Pearl: white body, charcoal keys, orange 2ndF.
  static const pearl = CalcSkin(
    id: 'pearl',
    name: 'Pearl',
    description: 'Pearl-white body, charcoal keys, orange 2ndF',
    background: Color(0xFFDCDDDF),
    bodyTop: Color(0xFFFBFBFA),
    body: Color(0xFFE6E7E8),
    bezel: Color(0xFF2C3036),
    brandText: Color(0xFF2A2E35),
    modifierKey: Color(0xFFE2762A),
    modifierText: Color(0xFFFFFFFF),
    functionKey: Color(0xFF3A3F47),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFF55595F),
    digitText: Color(0xFFFFFFFF),
    operatorKey: Color(0xFF6B7078),
    clearKey: Color(0xFFD9433C),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF55595F),
    discMark: Color(0xFFE6E7E8),
    labels: {
      LabelKind.shift: Color(0xFFD2691E),
      LabelKind.alpha: Color(0xFF2E7D5B),
      LabelKind.complex: Color(0xFF7A3FB8),
      LabelKind.stat: Color(0xFF1F5FB8),
      LabelKind.base: Color(0xFF1E7F3B),
      LabelKind.plain: Color(0xFF2A2E35),
      LabelKind.neutral: Color(0xFF5B6068),
    },
    lcd: LcdPalette(glass: Color(0xFFC3CCBC), ink: Color(0xFF1C221C)),
    solarStrip: Color(0xFF3B2E27),
  );

  /// Graphite: grey body, yellow 2nd key, light grey digits.
  static const graphite = CalcSkin(
    id: 'graphite',
    name: 'Graphite',
    description: 'Grey body, yellow 2nd key, light digit keys',
    background: Color(0xFF1A1B1E),
    bodyTop: Color(0xFF747A84),
    body: Color(0xFF545961),
    bezel: Color(0xFF2A2D32),
    brandText: Color(0xFFF2F3F5),
    modifierKey: Color(0xFFF2C230),
    modifierText: Color(0xFF1E1F22),
    functionKey: Color(0xFF2B2F36),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFFD6D9DE),
    digitText: Color(0xFF1E2126),
    operatorKey: Color(0xFFB0B5BD),
    clearKey: Color(0xFFF2C230),
    clearText: Color(0xFF1E1F22),
    disc: Color(0xFF3A3E45),
    discMark: Color(0xFFF2F3F5),
    labels: {
      LabelKind.shift: Color(0xFFF7D154),
      LabelKind.alpha: Color(0xFF9EE6B0),
      LabelKind.complex: Color(0xFFD3B5FF),
      LabelKind.stat: Color(0xFF9CC7FF),
      LabelKind.base: Color(0xFF9EE6B0),
      LabelKind.plain: Color(0xFFF2F3F5),
      LabelKind.neutral: Color(0xFFC9CDD3),
    },
    lcd: LcdPalette(glass: Color(0xFFC8CFC0), ink: Color(0xFF1B211B)),
    solarStrip: Color(0xFF2A221E),
  );

  /// Ocean: deep navy body, light grey keys, teal accents.
  static const ocean = CalcSkin(
    id: 'ocean',
    name: 'Ocean',
    description: 'Deep navy body, light grey keys, teal accents',
    background: Color(0xFF07101C),
    bodyTop: Color(0xFF1C2D4A),
    body: Color(0xFF101C31),
    bezel: Color(0xFF0A1220),
    brandText: Color(0xFFE3ECF8),
    modifierKey: Color(0xFF2BB3A3),
    modifierText: Color(0xFF06231F),
    functionKey: Color(0xFF26344F),
    functionText: Color(0xFFF1F5FB),
    digitKey: Color(0xFFDDE2EA),
    digitText: Color(0xFF14203A),
    operatorKey: Color(0xFFB7C1D1),
    clearKey: Color(0xFFE0574F),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF2BB3A3),
    discMark: Color(0xFF06231F),
    labels: {
      LabelKind.shift: Color(0xFF52D6C4),
      LabelKind.alpha: Color(0xFFFF8FA3),
      LabelKind.complex: Color(0xFFC9A3FF),
      LabelKind.stat: Color(0xFF8CC0FF),
      LabelKind.base: Color(0xFF8FE6A2),
      LabelKind.plain: Color(0xFFE3ECF8),
      LabelKind.neutral: Color(0xFFA9B6CB),
    },
    lcd: LcdPalette(glass: Color(0xFFBFD0C8), ink: Color(0xFF142026)),
    solarStrip: Color(0xFF221B18),
  );

  /// Indigo: deep blue body, white digit keys, soft blue modifiers.
  static const indigo = CalcSkin(
    id: 'indigo',
    name: 'Indigo',
    description: 'Deep blue body, white digit keys, blue modifiers',
    background: Color(0xFF0C1230),
    bodyTop: Color(0xFF2A3A86),
    body: Color(0xFF1A245C),
    bezel: Color(0xFF0F1640),
    brandText: Color(0xFFE8ECFF),
    modifierKey: Color(0xFF8EA6F0),
    modifierText: Color(0xFF0F1640),
    functionKey: Color(0xFF15194A),
    functionText: Color(0xFFFFFFFF),
    digitKey: Color(0xFFF3F4FA),
    digitText: Color(0xFF15194A),
    operatorKey: Color(0xFFD6DBF0),
    clearKey: Color(0xFFE85D5D),
    clearText: Color(0xFFFFFFFF),
    disc: Color(0xFF8EA6F0),
    discMark: Color(0xFF15194A),
    labels: {
      LabelKind.shift: Color(0xFFFFC857),
      LabelKind.alpha: Color(0xFFFF8FA3),
      LabelKind.complex: Color(0xFFD0B0FF),
      LabelKind.stat: Color(0xFF9CC7FF),
      LabelKind.base: Color(0xFF9EE6B0),
      LabelKind.plain: Color(0xFFE8ECFF),
      LabelKind.neutral: Color(0xFFB4BCE0),
    },
    lcd: LcdPalette(glass: Color(0xFFC3CDB6), ink: Color(0xFF1A2118)),
    solarStrip: Color(0xFF221A17),
  );

  static const all = [
    classic,
    midnight,
    highContrast,
    ivory,
    silver,
    black,
    slate,
    pearl,
    graphite,
    ocean,
    indigo,
  ];

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
