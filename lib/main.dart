import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_settings.dart';
import 'ui/calculator_screen.dart';
import 'ui/skin.dart';

void main() {
  _registerFontLicences();
  final settings = AppSettings();
  runApp(WCalcApp(settings: settings));
  settings.load().then((_) {
    // Web: ?skin=midnight previews a theme without saving it.
    final skin = Uri.base.queryParameters['skin'];
    if (skin != null) settings.preview(skinId: skin);
  });
}

/// Bundled OFL fonts appear in the in-app licence list.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Barlow Semi Condensed'], ofl);
    yield const LicenseEntryWithLineBreaks(
      ['Noto Sans Math (subset)'],
      'Copyright 2022 The Noto Project Authors. Licensed under the SIL Open Font License, Version 1.1.',
    );
  });
}

class WCalcApp extends StatelessWidget {
  WCalcApp({super.key, AppSettings? settings})
    : settings = settings ?? AppSettings();

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SkinScope(
          skin: CalcSkin.byId(settings.skinId),
          child: MaterialApp(
            title: 'W-Calc',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Barlow',
              fontFamilyFallback: const ['WCalcSymbols'],
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2B2F3A),
              ),
            ),
            home: const CalculatorScreen(),
          ),
        ),
      ),
    );
  }
}
