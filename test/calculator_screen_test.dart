import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:w_calc/main.dart';

Future<void> tapKey(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(Key('key-$name')));
  await tester.pump();
}

String lcdText(WidgetTester tester, String line) =>
    tester.widget<Text>(find.byKey(Key('lcd-$line'))).data ?? '';

void main() {
  testWidgets('shows initial display', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WCalcApp());
    expect(lcdText(tester, 'upper'), '');
    expect(lcdText(tester, 'lower'), '0.');
  });

  testWidgets('tapping digit keys updates the LCD, AC clears', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WCalcApp());
    await tapKey(tester, 'd1');
    await tapKey(tester, 'd2');
    expect(lcdText(tester, 'upper'), '12');

    await tapKey(tester, 'ac');
    expect(lcdText(tester, 'upper'), '');
  });

  testWidgets('SHIFT lights the S indicator', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WCalcApp());
    await tapKey(tester, 'shift');
    expect(lcdText(tester, 'indicators'), contains('S'));
  });
}
