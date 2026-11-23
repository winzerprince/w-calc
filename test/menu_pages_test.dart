import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/main.dart';

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

  testWidgets('manual: chapters, search and an article', (tester) async {
    await openApp(tester);
    await openMenuItem(tester, 'Manual');
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('For Scientific Plus'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('manual-search')), 'integral');
    await settle(tester);
    await tester.tap(find.byKey(const Key('hit-integration')));
    await settle(tester);
    expect(find.text('Integration'), findsWidgets);
    expect(find.text('Press'), findsWidgets);
    // Textbook-only topics are not offered on a two-line model.
    await tester.pageBack();
    await settle(tester);
    await tester.enterText(find.byKey(const Key('manual-search')), 'sigma');
    await settle(tester);
    expect(find.byKey(const Key('hit-sum')), findsNothing);
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

  testWidgets('switching to the basic model keeps memory and gates keys', (
    tester,
  ) async {
    final settings = await openApp(tester);
    // Store 7 in A on the full model.
    for (final k in ['d7', 'shift', 'rcl', 'negative']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await openMenuItem(tester, 'Calculator model');
    await tester.ensureVisible(find.byKey(const Key('model-basic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('model-basic')));
    await settle(tester);
    expect(settings.modelId, 'basic');
    await tester.pageBack();
    await settle(tester);
    // Close the menu overlay if still open.
    final close = find.byKey(const Key('app-menu-close'));
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close);
      await settle(tester);
    }
    expect(find.text('SCIENTIFIC BASIC'), findsOneWidget);
    expect(find.text('CONV'), findsNothing);
    // CONST is inert; the memory survived the switch.
    for (final k in ['ac', 'constant', 'rcl', 'negative']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    expect(lcd(tester, 'lower'), '7.');
  });

  testWidgets('long press on the LCD copies the result', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await openApp(tester);
    for (final k in ['d1', 'd2', 'multiply', 'd3', 'equals']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await tester.longPress(find.byKey(const Key('lcd-copy')));
    await settle(tester);
    expect(copied, ['36']);
    expect(find.text('Copied 36'), findsOneWidget);
  });

  testWidgets('keys can be activated by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await openApp(tester);
    tester.semantics.tap(find.semantics.byLabel('5'));
    await tester.pump();
    expect(lcd(tester, 'upper'), '5');
    handle.dispose();
  });

  testWidgets('grid model shows arrow keys instead of the disc', (
    tester,
  ) async {
    final settings = await openApp(tester);
    settings.update(modelId: 'grid');
    await settle(tester);
    expect(find.text('SCIENTIFIC GRID'), findsOneWidget);
    expect(find.text('2nd'), findsWidgets);
    for (final k in ['d4', 'left', 'right', 'd2', 'equals']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    expect(lcd(tester, 'lower'), '42.');
  });

  testWidgets('textbook model: dot LCD, fraction result, silver body', (
    tester,
  ) async {
    final settings = await openApp(tester);
    await openMenuItem(tester, 'Calculator model');
    await tester.ensureVisible(find.byKey(const Key('model-textbook')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('model-textbook')));
    await settle(tester);
    expect(settings.modelId, 'textbook');
    expect(settings.skinId, 'silver');
    await tester.pageBack();
    await settle(tester);
    final close = find.byKey(const Key('app-menu-close'));
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close);
      await settle(tester);
    }
    for (final k in [
      'd2',
      'fraction',
      'd3',
      'right',
      'add',
      'd1',
      'fraction',
      'd2',
      'equals',
    ]) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
    final text = tester
        .widget<Text>(find.byKey(const Key('lcd-text'), skipOffstage: false))
        .data;
    expect(text, endsWith('= fraction{7|6}'));
    // S⇔D exists on this keypad.
    await tester.tap(find.byKey(const Key('key-sd')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('lcd-text'), skipOffstage: false))
          .data,
      endsWith('= 1.166666667'),
    );
  });

  testWidgets('black textbook body has four arrow keys', (tester) async {
    final settings = await openApp(tester);
    settings.update(modelId: 'textbook2', skinId: 'black');
    await settle(tester);
    for (final k in ['up', 'down', 'left', 'right']) {
      expect(find.byKey(Key('key-$k')), findsOneWidget);
    }
    expect(find.text('TEXTBOOK PLUS II'), findsOneWidget);
  });
}
