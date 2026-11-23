import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/app/history_store.dart';
import 'package:w_calc/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HistoryStore.instance.resetForTest();
  });

  Future<AppSettings> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    await tester.runAsync(settings.load);
    await tester.pumpWidget(WCalcApp(settings: settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
    return settings;
  }

  testWidgets('first start shows the calculator tour; taps advance', (
    tester,
  ) async {
    final settings = await start(tester);
    expect(find.byKey(const Key('tour-overlay')), findsOneWidget);
    expect(find.textContaining('menu'), findsWidgets);
    expect(settings.seenTours, contains('calculator'));
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('tour-overlay')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 900));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('tour-overlay')), findsNothing);
  });

  testWidgets('skip closes the tour', (tester) async {
    await start(tester);
    final skip = find.byKey(const Key('tour-skip'));
    expect(skip, findsOneWidget);
    await tester.tap(skip, warnIfMissed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('tour-overlay')), findsNothing);
  });

  testWidgets('a seen tour does not come back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'wcalc.app.v1': '{"tours":["calculator"]}',
    });
    await start(tester);
    expect(find.byKey(const Key('tour-overlay')), findsNothing);
  });
}
