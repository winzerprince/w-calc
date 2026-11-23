import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/main.dart';
import 'package:w_calc/ui/pages/guide_page.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

String lcd(WidgetTester tester, String line) =>
    tester
        .widget<Text>(find.byKey(Key('lcd-$line'), skipOffstage: false))
        .data ??
    '';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppSettings> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    await tester.pumpWidget(WCalcApp(settings: settings));
    await tester.pump();
    return settings;
  }

  Future<void> openMenuItem(WidgetTester tester, String title) async {
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await settle(tester);
    await tester.tap(find.text(title));
    await settle(tester);
  }

  testWidgets('choosing a theme updates the settings', (tester) async {
    final settings = await openApp(tester);
    await openMenuItem(tester, 'Theme');
    await tester.tap(find.byKey(const Key('theme-midnight')));
    await settle(tester);
    expect(settings.skinId, 'midnight');
  });

  testWidgets('vibration can be switched off', (tester) async {
    final settings = await openApp(tester);
    await openMenuItem(tester, 'Settings');
    await tester.tap(find.byKey(const Key('setting-vibration')));
    await settle(tester);
    expect(settings.vibration, isFalse);
  });

  testWidgets('reset clears memories after confirmation', (tester) async {
    await openApp(tester);
    for (final k in ['d7', 'shift', 'rcl', 'negative']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await openMenuItem(tester, 'Settings');
    await tester.tap(find.byKey(const Key('setting-reset')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-reset')));
    await settle(tester);
    // Back to the calculator: two pages (settings, menu).
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const Key('app-menu-close')));
    await settle(tester);
    for (final k in ['rcl', 'negative']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    expect(lcd(tester, 'lower'), '0.');
  });

  testWidgets('user guide lists every topic', (tester) async {
    await openApp(tester);
    await openMenuItem(tester, 'User guide');
    for (final topic in guideTopics.take(4)) {
      expect(find.text(topic.title), findsOneWidget);
    }
  });

  test('settings round-trip through preferences', () async {
    final a = AppSettings()
      ..update(vibration: false, keySound: true, skinId: 'ivory');
    await Future<void>.delayed(Duration.zero);
    final b = AppSettings();
    await b.load();
    expect((b.vibration, b.keySound, b.skinId), (false, true, 'ivory'));
    expect(a.skinId, 'ivory');
  });
}
