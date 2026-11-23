import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/app/calc_model.dart';
import 'package:w_calc/app/history_store.dart';
import 'package:w_calc/main.dart';

/// Every model renders without layout errors and calculates 1 + 2.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HistoryStore.instance.resetForTest();
  });

  for (final model in CalcModel.all) {
    testWidgets('${model.name}: renders and adds', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final settings = AppSettings()
        ..update(modelId: model.id, skinId: model.skinId);
      await tester.pumpWidget(WCalcApp(settings: settings));
      await tester.pump();
      for (final k in ['d1', 'add', 'd2', 'equals']) {
        await tester.tap(find.byKey(Key('key-$k')));
        await tester.pump();
      }
      // = may compute after a busy frame.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final mirror = find.byKey(
        Key(model.family == CalcFamily.textbook ? 'lcd-text' : 'lcd-lower'),
        skipOffstage: false,
      );
      expect(tester.widget<Text>(mirror).data, contains('3'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final model in CalcModel.all) {
    testWidgets('${model.name}: 200 random key taps render without errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final settings = AppSettings()
        ..update(modelId: model.id, skinId: model.skinId);
      await tester.pumpWidget(WCalcApp(settings: settings));
      await tester.pump();
      final keys = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('key-') &&
            (w.key! as ValueKey<String>).value != 'key-on',
      );
      final count = keys.evaluate().length;
      final rnd = math.Random(model.id.hashCode);
      for (var i = 0; i < 200; i++) {
        await tester.tap(keys.at(rnd.nextInt(count)), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
        // Slow keys finish after a busy frame.
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'tap $i');
      }
    });
  }
}
