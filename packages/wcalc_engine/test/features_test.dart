import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  group('basic model', () {
    late Calculator calc;

    setUp(() => calc = Calculator(features: CalcFeatures.basic));

    DisplayState press(String sequence) {
      keys(sequence).forEach(calc.press);
      return calc.display;
    }

    test('one mode page with COMP SD REG', () {
      final d = press('MODE');
      expect(d.upper, 'COMP SD REG');
      expect(d.menuMarks, {1: '1', 6: '2', 9: '3'});
      expect(press('MODE').upper, 'Deg Rad Gra');
    });
    test('mode choices map to the right modes', () {
      press('MODE 2');
      expect(calc.mode, CalcMode.sd);
      press('MODE 3');
      expect(calc.display.upper, 'Lin Log Exp→');
    });
    test('CONST, CONV, ∫dx, CALC and SOLVE do nothing', () {
      expect(press('CONST').upper, '');
      expect(press('CONV').upper, '');
      expect(press('∫dx').upper, '');
      expect(press('d/dx').upper, '');
      expect(press('1 + X CALC').upper, '1+X');
      expect(press('SOLVE').upper, '1+X');
    });
    test('ordinary calculation is unchanged', () {
      expect(press('AC sin 30 =').lower, '0.5');
    });
  });

  test('full model keeps the reference mode pages', () {
    final calc = Calculator();
    calc.press(CalcKey.mode);
    expect(calc.display.upper, 'COMP CMPLX');
    expect(calc.features.modes, hasLength(CalcMode.values.length));
  });

  test('allows() reports SHIFT functions separately', () {
    expect(CalcFeatures.basic.allows(CalcKey.constant, shift: false), isFalse);
    expect(CalcFeatures.basic.allows(CalcKey.sin, shift: true), isTrue);
    expect(CalcFeatures.full.allows(CalcKey.calc, shift: true), isTrue);
  });

  test('state saved in a mode the model lacks restores to COMP', () {
    final full = Calculator();
    for (final k in parseKeySequence('MODE MODE 3')) {
      full.press(k);
    }
    expect(full.mode, CalcMode.base);
    final basic = Calculator(features: CalcFeatures.basic)
      ..restoreState(full.saveState());
    expect(basic.mode, CalcMode.comp);
  });
}
