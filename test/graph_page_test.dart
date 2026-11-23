import 'package:flutter/gestures.dart';
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
    expect(find.byKey(const Key('graph-expr-0')), findsOneWidget);
  });

  Future<void> openGraph(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await settle(tester);
    await tester.tap(find.text('Graph'));
    await settle(tester);
  }

  Future<void> keys(WidgetTester tester, List<String> ids) async {
    for (final k in ids) {
      await tester.tap(find.byKey(Key('gx-key-$k')));
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('graph mode: type with the keypad, trace a point', (
    tester,
  ) async {
    await open(tester);
    await openGraph(tester);
    expect(find.byKey(const Key('graph-expr-0')), findsOneWidget);
    // Replace x² by 2x+1.
    await tester.tap(find.byKey(const Key('graph-expr-0')));
    await settle(tester);
    expect(find.byKey(const Key('gx-keypad')), findsOneWidget);
    await keys(tester, ['back', 'back', 'back', 'back', '2', 'x', 'plus', '1']);
    final canvas = tester.getRect(find.byKey(const Key('graph-canvas')));
    await tester.tapAt(canvas.center);
    await settle(tester);
    expect(find.byKey(const Key('gx-keypad')), findsNothing);
    expect(find.byKey(const Key('graph-trace')), findsOneWidget);
    // Tapping near the root snaps to it.
    expect(find.text('(−0.5, 0)'), findsOneWidget);
    // Undo brings x² back.
    await tester.tap(find.byKey(const Key('graph-undo')));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('functions panel, errors, values and sliders', (tester) async {
    await open(tester);
    await openGraph(tester);
    await tester.tap(find.byKey(const Key('graph-add')));
    await settle(tester);
    // a·sin x: the free a offers a slider.
    await keys(tester, ['abc', 'letter-a', 'abc', 'funcs', 'fn-sin', 'x']);
    expect(find.byKey(const Key('graph-slider-add-a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('graph-slider-add-a')));
    await settle(tester);
    expect(find.byKey(const Key('graph-slider-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('graph-play-2')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('graph-play-2')));
    await settle(tester);
    // A constant shows its value; a bad row shows a warning.
    await tester.tap(find.byKey(const Key('graph-add')));
    await settle(tester);
    await keys(tester, ['2', 'plus', '3']);
    expect(find.text('= 5'), findsOneWidget);
    await keys(tester, ['plus']);
    expect(find.byKey(const Key('graph-error-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode: table of values, delete all', (tester) async {
    await open(tester);
    await openGraph(tester);
    await tester.tap(find.byKey(const Key('graph-edit')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('graph-table-0')));
    await settle(tester);
    expect(find.byKey(const Key('graph-values')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    await tester.tap(find.byKey(const Key('graph-delete-all')));
    await settle(tester);
    expect(find.byKey(const Key('graph-expr-0')), findsNothing);
  });

  testWidgets('settings panel: grid, log axis, degrees', (tester) async {
    await open(tester);
    await openGraph(tester);
    await tester.tap(find.byKey(const Key('graph-settings')));
    await settle(tester);
    expect(find.byKey(const Key('graph-settings-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('graph-opt-minor')));
    await settle(tester);
    await tester.tap(find.text('Logarithmic').first);
    await settle(tester);
    await tester.tap(find.text('Degrees'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('graph-home')));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph mode remembers old saved functions', (tester) async {
    SharedPreferences.setMockInitialValues({
      'wcalc.graph.v1': ['x^3', 'sin(x)'],
    });
    await open(tester);
    await openGraph(tester);
    expect(find.byKey(const Key('graph-expr-1')), findsOneWidget);
    expect(find.byKey(const Key('graph-expr-2')), findsNothing);
  });

  testWidgets('landscape puts the list beside the plot; summary for TalkBack', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WCalcApp(settings: AppSettings()));
    await tester.pump();
    await openGraph(tester);
    final canvas = tester.getRect(find.byKey(const Key('graph-canvas')));
    final list = tester.getRect(find.byKey(const Key('graph-add')));
    expect(list.left, greaterThan(canvas.right - 1));
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp(r'Graph of y = x\^\(2\)')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('power hint, back to the main line, closing functions', (
    tester,
  ) async {
    await open(tester);
    await openGraph(tester);
    await tester.tap(find.byKey(const Key('graph-add')));
    await settle(tester);
    await keys(tester, ['x', 'pow']);
    expect(find.byKey(const Key('graph-hint')), findsOneWidget);
    await keys(tester, ['2']);
    // Tapping the row beside the expression leaves the exponent: the next
    // digit goes on the main line.
    final row = tester.getRect(find.byKey(const Key('graph-expr-1')));
    await tester.tapAt(Offset(row.right + 60, row.center.dy));
    await settle(tester);
    await keys(tester, ['plus', '1']);
    // Functions panel: the X and a tap outside both close it.
    await keys(tester, ['funcs']);
    expect(find.byKey(const Key('gx-funcs')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gx-funcs-close')));
    await settle(tester);
    expect(find.byKey(const Key('gx-funcs')), findsNothing);
    await keys(tester, ['funcs']);
    await tester.tapAt(row.center);
    await settle(tester);
    expect(find.byKey(const Key('gx-funcs')), findsNothing);
    expect(tester.takeException(), isNull);
    // Let the hint time out.
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('settings panel stays on screen', (tester) async {
    await open(tester);
    await openGraph(tester);
    await tester.tap(find.byKey(const Key('graph-settings')));
    await settle(tester);
    final panel = tester.getRect(find.byKey(const Key('graph-settings-panel')));
    final screen = tester.getRect(find.byType(Scaffold).first);
    expect(panel.left, greaterThanOrEqualTo(screen.left));
    expect(panel.right, lessThanOrEqualTo(screen.right));
    expect((panel.center.dx - screen.center.dx).abs(), lessThan(2));
  });

  testWidgets('mouse wheel zooms the graph', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('app-menu-button')));
    await settle(tester);
    await tester.tap(find.text('Graph'));
    await settle(tester);
    final c = tester.getCenter(find.byKey(const Key('graph-canvas')));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(c));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
