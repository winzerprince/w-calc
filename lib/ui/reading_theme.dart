import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import 'keypad_layout.dart';
import 'skin.dart';

/// Reading theme for the manual and graph: light on light calculator bodies, dark on
/// dark ones, so it feels like part of the same device.
ThemeData readingTheme(BuildContext context) {
  final skin = CalcSkin.of(context);
  final dark = switch (SettingsScope.maybeOf(context)?.appearance) {
    'light' => false,
    'dark' => true,
    _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };
  final seeded = ColorScheme.fromSeed(
    seedColor: skin.label(LabelKind.shift),
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  // Plain white / black paper; the model's accent only for highlights.
  final scheme = seeded.copyWith(
    surface: dark ? const Color(0xFF111215) : Colors.white,
    onSurface: dark ? const Color(0xFFEDEDED) : const Color(0xFF16181D),
    surfaceContainerLowest: dark ? const Color(0xFF0B0C0E) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xFF17181B)
        : const Color(0xFFF7F7F8),
    surfaceContainer: dark ? const Color(0xFF1B1C20) : const Color(0xFFF2F3F5),
    surfaceContainerHigh: dark
        ? const Color(0xFF212327)
        : const Color(0xFFECEDF0),
    surfaceContainerHighest: dark
        ? const Color(0xFF282A2F)
        : const Color(0xFFE6E7EA),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Barlow',
    fontFamilyFallback: const ['WCalcSymbols'],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// Every menu page: the reading theme (System / Light / Dark from settings)
/// and the chosen text size. The calculator itself is not affected.
class AppPageTheme extends StatelessWidget {
  const AppPageTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = SettingsScope.maybeOf(context)?.textScale ?? 1.0;
    return Theme(
      data: readingTheme(context),
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );
  }
}
