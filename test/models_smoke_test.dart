import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w_calc/app/app_settings.dart';
import 'package:w_calc/app/calc_model.dart';
import 'package:w_calc/main.dart';

/// Every model renders without layout errors and calculates 1 + 2.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
}
