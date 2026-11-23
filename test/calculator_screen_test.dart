import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/main.dart';

Future<void> tapKey(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(Key('key-$name')));
  await tester.pump();
}

String lcdText(WidgetTester tester, String line) =>
    tester
        .widget<Text>(find.byKey(Key('lcd-$line'), skipOffstage: false))
        .data ??
    '';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows initial display', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    expect(lcdText(tester, 'upper'), '');
    expect(lcdText(tester, 'lower'), '0.');
  });

  testWidgets('tapping digit keys updates the LCD, AC clears', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tapKey(tester, 'd1');
    await tapKey(tester, 'd2');
    expect(lcdText(tester, 'upper'), '12');

    await tapKey(tester, 'ac');
    expect(lcdText(tester, 'upper'), '');
  });

  testWidgets('keypad computes 2 ÷ 3 × 1 EXP 20 with exponent display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    for (final k in [
      'd2',
      'divide',
      'd3',
      'multiply',
      'd1',
      'exp',
      'd2',
      'd0',
      'equals',
    ]) {
      await tapKey(tester, k);
    }
    expect(lcdText(tester, 'lower'), '6.666666667');
    expect(lcdText(tester, 'exponent'), '19');
  });

  testWidgets('memories persist across app restarts', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tester.pump(const Duration(milliseconds: 100));
    for (final k in ['d4', 'd2', 'shift', 'rcl', 'negative']) {
      await tapKey(tester, k);
    }
    await tester.pump(const Duration(milliseconds: 50));

    // New app instance reads the saved state.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(WCalcApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tapKey(tester, 'rcl');
    await tapKey(tester, 'negative');
    expect(lcdText(tester, 'lower'), '42.');
  });

  testWidgets('W-Calc opens the menu; ✕ closes it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app-menu')), findsOneWidget);
    for (final title in ['Settings', 'Theme', 'Manual', 'About W-Calc']) {
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Theme'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('theme-midnight')), findsOneWidget);
    await tester.pageBack();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('theme-midnight')), findsNothing);

    await tester.tap(find.byKey(const Key('app-menu-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app-menu')), findsNothing);
  });

  testWidgets('Escape closes the menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app-menu')), findsNothing);
  });

  testWidgets('SHIFT lights the S indicator', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tapKey(tester, 'shift');
    expect(lcdText(tester, 'indicators'), contains('shift'));
  });

  testWidgets('landscape layout fits without overflow and works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tapKey(tester, 'd4');
    await tapKey(tester, 'equals');
    expect(lcdText(tester, 'lower'), '4.');
  });

  testWidgets('small phone portrait fits without overflow', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WCalcApp());
    await tapKey(tester, 'd9');
    expect(lcdText(tester, 'upper'), '9');
  });

  for (final (name, size, ratio) in [
    ('tablet portrait', const Size(1600, 2560), 2.0),
    ('7-inch tablet portrait', const Size(1200, 1920), 2.0),
    ('tall phone', const Size(1080, 2400), 2.625),
  ]) {
    testWidgets('$name keeps calculator proportions', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(WCalcApp());
      final body = tester.getSize(find.byKey(const Key('calc-body')));
      expect(body.width, lessThanOrEqualTo(620));
      expect(body.height / body.width, inInclusiveRange(1.6, 2.3));
      await tapKey(tester, 'd8');
      expect(lcdText(tester, 'upper'), '8');
    });
  }

  testWidgets('solar panel toggles focus (full-screen) mode', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          calls.add('${call.arguments}');
        }
        return null;
      },
    );
    await tester.pumpWidget(WCalcApp());
    await tester.tap(find.byKey(const Key('solar-panel')));
    await tester.pump();
    expect(calls.last, contains('immersiveSticky'));
    await tester.tap(find.byKey(const Key('solar-panel')));
    await tester.pump();
    expect(calls.last, contains('edgeToEdge'));
  });

  testWidgets('long press on a key explains its other functions', (
    tester,
  ) async {
    await tester.pumpWidget(WCalcApp());
    await tester.longPress(find.byKey(const Key('key-sin')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('SHIFT ▸ sin⁻¹'), findsOneWidget);
  });

  testWidgets('history button lists earlier calculations', (tester) async {
    await tester.pumpWidget(WCalcApp());
    expect(find.byKey(const Key('history-button')), findsNothing);
    for (final k in [
      'd1',
      'add',
      'd2',
      'equals',
      'd5',
      'multiply',
      'd5',
      'equals',
    ]) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('history-button')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1+2'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });
}
