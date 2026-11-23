import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WCalcApp(settings: AppSettings()));
    await tester.pump();
  }

  testWidgets('graph button appears when the calculation uses X', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('graph-button')), findsNothing);
    // X² + 1 on the two-line model: ALPHA ) types X.
    for (final k in ['alpha', 'closeParen', 'square', 'add', 'd1']) {
      await tester.tap(find.byKey(Key('key-$k')));
      await tester.pump();
    }
    await settle(tester);
    expect(find.byKey(const Key('graph-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('graph-button')));
    await settle(tester);
    expect(find.byKey(const Key('graph-canvas')), findsOneWidget);
    expect(find.text('x²+1'), findsOneWidget);
  });

  testWidgets('graph mode: type a function, trace a point', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await settle(tester);
    await tester.tap(find.text('Graph'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('graph-formula-0')), '2x+1');
    await settle(tester);
    final canvas = tester.getRect(find.byKey(const Key('graph-canvas')));
    await tester.tapAt(canvas.center);
    await settle(tester);
    expect(find.byKey(const Key('graph-trace')), findsOneWidget);
    expect(find.text('(0, 1)'), findsOneWidget);
    // A bad formula shows a message instead of crashing.
    await tester.tap(find.byKey(const Key('graph-add')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('graph-formula-1')), 'x ? 2');
    await settle(tester);
    expect(find.textContaining('Unexpected'), findsOneWidget);
  });

  testWidgets('table of values', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await settle(tester);
    await tester.tap(find.text('Graph'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('graph-table')));
    await settle(tester);
    expect(find.byKey(const Key('graph-values')), findsOneWidget);
    expect(find.text('y = x^2'), findsOneWidget);
  });
}
