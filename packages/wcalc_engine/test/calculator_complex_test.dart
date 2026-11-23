import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  late Calculator calc;

  setUp(
    () => calc = Calculator()
      ..press(CalcKey.mode)
      ..press(CalcKey.d2),
  );

  DisplayState press(String sequence) {
    keys(sequence).forEach(calc.press);
    return calc.display;
  }

  /// (result line, shows-imaginary-mark, shows-angle-mark)
  (String, bool, bool) part(String sequence) {
    final d = press(sequence);
    return (
      d.lower,
      d.indicators.contains(Indicator.imaginary),
      d.indicators.contains(Indicator.angleMark),
    );
  }

  test('MODE 2 enters CMPLX with its indicator; MODE 1 leaves', () {
    expect(calc.display.indicators, contains(Indicator.cmplx));
    expect(press('MODE 1').indicators, isNot(contains(Indicator.cmplx)));
  });

  group('manual p.45-47', () {
    test('(2 + 6i) ÷ (2i) = 3 − i', () {
      expect(press('( 2 + 6 i ) ÷ ( 2 i )').upper, '(2+6i)÷(2i)');
      expect(part('='), ('3.', false, false));
      expect(calc.display.indicators, contains(Indicator.reIm));
      expect(part('ReIm'), ('-1.', true, false));
      expect(part('ReIm'), ('3.', false, false));
    });
    test('√2∠45 = 1 + i', () {
      expect(part('√ 2 ∠ 45 ='), ('1.', false, false));
      expect(part('ReIm'), ('1.', true, false));
    });
    test('Conjg(2 + 3i) = 2 − 3i', () {
      expect(part('Conjg ( 2 + 3 i ) ='), ('2.', false, false));
      expect(part('ReIm'), ('-3.', true, false));
    });
    test('Abs(1 + i), arg(1 + i)', () {
      expect(press('Abs ( 1 + i ) =').lower, '1.414213562');
      expect(press('arg ( 1 + i ) =').lower, '45.');
    });
    test('1 + i ▶r∠θ = 1.414213562 ∠45', () {
      expect(press('1 + i toPolar').upper, '1+i▶r∠θ');
      expect(part('='), ('1.414213562', false, false));
      expect(part('ReIm'), ('45.', false, true));
    });
    test('√2∠45 ▶a+bi = 1 + i', () {
      expect(part('√ 2 ∠ 45 toRect ='), ('1.', false, false));
      expect(part('ReIm'), ('1.', true, false));
    });
  });

  group('format setting r∠θ', () {
    test('Disp page appears in CMPLX and switches to polar', () {
      expect(press('MODE MODE MODE MODE MODE MODE 1 >').upper, 'a+bi r∠θ');
      press('2');
      expect(calc.display.indicators, contains(Indicator.polar));
      expect(part('1 + i ='), ('1.414213562', false, false));
      expect(part('ReIm'), ('45.', false, true));
    });
    test('▶a+bi overrides the polar setting', () {
      press('MODE MODE MODE MODE MODE MODE 1 > 2');
      expect(part('1 + i toRect ='), ('1.', false, false));
    });
  });

  group('arithmetic and errors', () {
    test('i² = -1', () => expect(press('i x2 =').lower, '-1.'));
    test('implied multiplication with i', () {
      expect(part('3 i × 2 ='), ('0.', false, false));
      expect(part('ReIm'), ('6.', true, false));
    });
    test('real result shows no Re⇔Im indicator', () {
      expect(press('i × i =').indicators, isNot(contains(Indicator.reIm)));
    });
    test('functions of complex numbers → Math ERROR', () {
      expect(press('sin ( 1 + i ) =').upper, 'Math ERROR');
    });
    test('division by 0 → Math ERROR', () {
      expect(press('AC ( 1 + i ) ÷ 0 =').upper, 'Math ERROR');
    });
    test('complex Ans and variables', () {
      press('2 + 3 i STO kA');
      expect(part('AC A × 2 ='), ('4.', false, false));
      expect(part('ReIm'), ('6.', true, false));
    });
    test('SHIFT = is not % in CMPLX', () {
      expect(press('AC 50 × 2 ReIm').upper, '50×2');
    });
    test('integration is not available in CMPLX', () {
      expect(press('AC ∫dx').upper, '');
    });
    test('mode change clears history', () {
      press('1 + 1 = MODE 1');
      expect(press('up').upper, '');
    });
    test('complex Ans survives a snapshot', () {
      press('1 + 2 i =');
      final c = Calculator()..restoreState(calc.saveState());
      expect(c.display.indicators, contains(Indicator.cmplx));
      keys('Ans × i =').forEach(c.press);
      expect(c.display.lower, '-2.');
    });
  });
}
