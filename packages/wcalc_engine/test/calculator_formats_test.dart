import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  late Calculator calc;

  setUp(() => calc = Calculator());

  DisplayState press(String sequence) {
    keys(sequence).forEach(calc.press);
    return calc.display;
  }

  void vector(String sequence, String mantissa, [String? exponent]) {
    final d = press(sequence);
    expect((d.lower, d.exponent), (mantissa, exponent), reason: sequence);
  }

  const disp = 'MODE MODE MODE MODE MODE MODE 1';

  group('fractions (manual p.19-20)', () {
    test('2/3 + 1/5 = 13/15', () => vector('2 ab/c 3 + 1 ab/c 5 =', '13┘15.'));
    test('3 1/4 + 1 2/3 = 4 11/12', () {
      vector('3 ab/c 1 ab/c 4 + 1 ab/c 2 ab/c 3 =', '4┘11┘12.');
    });
    test(
      '1/2 + 1.6 = 2.1 (mixing gives decimal)',
      () => vector('1 ab/c 2 + 1.6 =', '2.1'),
    );
    test(
      'input shows the fraction mark',
      () => expect(press('2 ab/c 3').upper, '2┘3'),
    );
    test('2.75 → 2 3/4 → 11/4', () {
      vector('2.75 =', '2.75');
      vector('ab/c', '2┘3┘4.');
      vector('d/c', '11┘4.');
    });
    test('1/2 ↔ 0.5', () {
      vector('1 ab/c 2 =', '1┘2.');
      vector('ab/c', '0.5');
      vector('ab/c', '1┘2.');
    });
    test('1 2/3 ↔ 5/3', () {
      vector('1 ab/c 2 ab/c 3 =', '1┘2┘3.');
      vector('d/c', '5┘3.');
      vector('d/c', '1┘2┘3.');
    });
    test('d/c display setting', () {
      press('$disp > 2');
      vector('2 ab/c 3 + 1 =', '5┘3.');
    });
    test('mixed-fraction input with d/c setting is an error', () {
      press('$disp > 2');
      expect(press('1 ab/c 2 ab/c 3 =').upper, 'Syntax ERROR');
    });
    test('fractions keep exact results through Ans', () {
      press('1 ab/c 3 =');
      vector('Ans × 3 =', '1.');
      vector('AC 1 ab/c 3 = Ans + 1 ab/c 6 =', '1┘2.');
    });
    test('fraction squared stays exact', () => vector('2 ab/c 3 x2 =', '4┘9.'));
    test('denominator 0 → Math ERROR', () {
      expect(press('1 ab/c 0 =').upper, 'Math ERROR');
    });
    test('decimal parts in a fraction → Syntax ERROR', () {
      expect(press('1.5 ab/c 2 =').upper, 'Syntax ERROR');
    });
    test('conversion does not change Ans', () {
      press('1 ab/c 4 = ab/c');
      vector('Ans × 4 =', '1.');
    });
  });

  group('percent (manual p.20-22)', () {
    test('12% of 1500', () => vector('1500 × 12 %', '180.'));
    test('660 is what % of 880', () => vector('660 ÷ 880 %', '75.'));
    test('2500 increased by 15%', () => vector('2500 × 15 % +', '2875.'));
    test('3500 decreased by 25%', () => vector('3500 × 25 % -', '2625.'));
    test('sum decreased by 20% via a variable', () {
      press('168 + 98 + 734 = Ans STO kA');
      vector('A × 20 % -', '800.');
    });
    test('300 added to 500', () => vector('300 + 500 %', '160.'));
    test('40 → 46 and → 48 by replay', () {
      vector('46 - 40 %', '15.');
      vector('< < < < < < 8 =', '20.');
    });
    test('% shows on the expression line', () {
      expect(press('1500 × 12 %').upper, '1500×12%');
    });
  });

  group('sexagesimal (manual p.22-23)', () {
    test('input 2°0′30″', () {
      expect(press('2 dms 0 dms 30 dms').upper, '2°0°30°');
      vector('=', '2°0°30.');
    });
    test('2°20′30″ + 0°39′30″ = 3°0′0″', () {
      vector('2 dms 20 dms 30 dms + 0 dms 39 dms 30 dms =', '3°0°0.');
    });
    test('12°34′56″ × 3.45', () {
      vector('12 dms 34 dms 56 dms × 3.45 =', '43°24°31.2');
    });
    test('decimal ↔ sexagesimal', () {
      vector('2.258 =', '2.258');
      vector('toDms', '2°15°28.8');
      vector('dms', '2.258');
    });
    test(
      'sexagesimal value works in trig',
      () => vector('sin 30 dms =', '0.5'),
    );
  });

  group('ENG (manual p.24)', () {
    test('56088 m → km', () => vector('56088 = ENG', '56.088', '03'));
    test('0.08125 g → mg', () => vector('0.08125 = ENG', '81.25', '-03'));
    test('1234: ENG, ENG shifts the point right', () {
      vector('1234 =', '1234.');
      vector('ENG', '1.234', '03');
      vector('ENG', '1234.', '00');
    });
    test('123: ← shifts the point left', () {
      vector('123 =', '123.');
      vector('engLeft', '0.123', '03');
      vector('engLeft', '0.000123', '06');
    });
    test('a new calculation drops the ENG view', () {
      press('1234 = ENG');
      vector('2 =', '2.');
    });
  });

  group('engineering symbols (manual p.25)', () {
    test('Disp EngON shows the Eng indicator', () {
      expect(press('$disp 1').indicators, contains(Indicator.eng));
    });
    test('100m × 5μ = 500n', () {
      press('$disp 1');
      expect(press('100 SHIFT 5 × 5 SHIFT 4').upper, '100m×5μ');
      final d = press('=');
      expect((d.lower, d.engSymbol), ('500.', 'n'));
    });
    test('9 ÷ 10 = 900m, ← 0.9, ENG 900m', () {
      press('$disp 1');
      final a = press('9 ÷ 10 =');
      expect((a.lower, a.engSymbol), ('900.', 'm'));
      final b = press('engLeft');
      expect((b.lower, b.engSymbol), ('0.9', null));
      final c = press('ENG');
      expect((c.lower, c.engSymbol), ('900.', 'm'));
    });
    test('symbols are not typed when EngOFF', () {
      expect(press('100 SHIFT 5').upper, '100');
    });
    test('EngOFF via Disp 2', () {
      press('$disp 1 $disp 2');
      expect(calc.display.indicators, isNot(contains(Indicator.eng)));
    });
  });

  group('Disp setup screens', () {
    test('screens and paging', () {
      expect(press(disp).upper, 'EngON EngOFF');
      expect(press('>').upper, 'ab/c d/c');
      expect(press('>').upper, 'Dot Comma');
      expect(press('>').upper, 'Dot Comma');
      expect(press('<').upper, 'ab/c d/c');
      expect(press('AC').upper, '');
    });
    test('Comma setting is reported to the display', () {
      press('$disp > > 2');
      expect(calc.display.decimalComma, isTrue);
      press('$disp > > 1');
      expect(calc.display.decimalComma, isFalse);
    });
    test('settings persist in snapshots', () {
      press('$disp 1 $disp > 2 $disp > > 2');
      final c = Calculator()..restoreState(calc.saveState());
      final s = c.displaySettings;
      expect(
        (s.engOn, s.improperFractions, s.decimalComma),
        (true, true, true),
      );
    });
    test('fraction Ans persists exactly', () {
      press('1 ab/c 3 =');
      final c = Calculator()..restoreState(calc.saveState());
      keys('Ans × 3 =').forEach(c.press);
      expect(c.display.lower, '1.');
    });
  });
}
