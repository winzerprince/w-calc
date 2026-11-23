import 'dart:math';

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  late Calculator calc;

  setUp(() => calc = Calculator(random: Random(42)));

  DisplayState press(String sequence) {
    keys(sequence).forEach(calc.press);
    return calc.display;
  }

  void vector(String sequence, String mantissa, [String? exponent]) {
    final d = press(sequence);
    expect((d.lower, d.exponent), (mantissa, exponent), reason: sequence);
  }

  const rad = 'MODE MODE MODE MODE 2';
  const gra = 'MODE MODE MODE MODE 3';

  group('manual p.32-36 function examples', () {
    test('sin 30 = 0.5 (Deg)', () => vector('sin 30 =', '0.5'));
    test('cos(π/3) = 0.5 (Rad)', () => vector('$rad cos ( pi ÷ 3 ) =', '0.5'));
    test(
      'tan(-35) (Gra)',
      () => vector('$gra tan ( (-) 35 ) =', '-0.612800788'),
    );
    test('sin⁻¹ 0.5 = 30', () => vector('asin 0.5 =', '30.'));
    test('cos⁻¹(√2/2) ÷ π = 0.25 (Rad)', () {
      press('$rad acos ( √ 2 ÷ 2 ) =');
      vector('Ans ÷ pi =', '0.25');
    });
    test('tan⁻¹ 0.741', () => vector('atan 0.741 =', '36.53844577'));
    test('sinh 3.6', () => vector('hyp sin 3.6 =', '18.28545536'));
    test('sinh⁻¹ 30', () => vector('hyp SHIFT sin 30 =', '4.094622224'));
    test('4.25 rad → deg', () => vector('4.25 DRG 2 =', '243.5070629'));
    test('e^10', () => vector('e^ 10 =', '22026.46579'));
    test('10^1.5', () => vector('10^ 1.5 =', '31.6227766'));
    test('2^-3', () => vector('2 ^ (-) 3 =', '0.125'));
    test('(-2)^4', () => vector('( (-) 2 ) ^ 4 =', '16.'));
    test('log 1.23', () => vector('log 1.23 =', '0.089905111'));
    test('ln 90', () => vector('ln 90 =', '4.49980967'));
    test('ln e = 1', () => vector('ln e =', '1.'));
    test('√2 + √3 × √5', () => vector('√ 2 + √ 3 × √ 5 =', '5.287196909'));
    test(
      '∛5 + ∛-27',
      () => vector('cbrt 5 + cbrt ( (-) 27 ) =', '-1.290024053'),
    );
    test('7th root of 123', () => vector('7 xroot 123 =', '1.988647795'));
    test('123 + 30²', () => vector('123 + 30 x2 =', '1023.'));
    test('12³', () => vector('12 x3 =', '1728.'));
    test('1 / (1/3 - 1/4)', () => vector('( 3 x-1 - 4 x-1 ) x-1 =', '12.'));
    test('(5+3)!', () => vector('( 5 + 3 ) fact =', '40320.'));
    test('7P4', () => vector('7 nPr 4 =', '840.'));
    test('10C4', () => vector('10 nCr 4 =', '210.'));
  });

  group('priority', () {
    test('-2^4 = -16', () => vector('(-) 2 ^ 4 =', '-16.'));
    test(
      'Type A binds tighter than ^: 2^3² = 512',
      () => vector('2 ^ 3 x2 =', '512.'),
    );
    test('^ is left-to-right: 2^3^2 = 64', () => vector('2 ^ 3 ^ 2 =', '64.'));
    test('Type B takes the following power: sin 30² uses 900', () {
      vector('sin 30 x2 =', '0.');
    });
    test('implied ×: 2π', () => vector('2 pi =', '6.283185307'));
    test('implied × before function: 2√9 = 6', () => vector('2 √ 9 =', '6.'));
    test('nPr below ×: 2 × 5 nPr 2 = 40', () => vector('2 × 5 nPr 2 =', '40.'));
  });

  group('after a result', () {
    test('Type A key continues with Ans', () {
      expect(press('3 = x2').upper, 'Ans²');
      vector('=', '9.');
    });
    test('^ continues with Ans', () => vector('2 = ^ 10 =', '1024.'));
    test('Type B key starts a new expression', () {
      expect(press('3 = sin').upper, 'sin ');
    });
    test('Rnd applies to Ans (manual p.38, Fix 3)', () {
      press('MODE MODE MODE MODE MODE 1 3');
      vector('10 ÷ 3 × 3 =', '10.000');
      vector('10 ÷ 3 = Rnd × 3 =', '9.999');
    });
    test('DRG marker after a result applies to Ans', () {
      press('180 =');
      expect(press('DRG').upper, isNot('180'));
      press('1');
      expect(calc.display.upper, 'Ans°');
    });
  });

  group('upper line text', () {
    test('functions show their names', () {
      expect(press('sin 3 + tan').upper, 'sin 3+tan ');
      expect(press('AC asin').upper, 'sin⁻¹ ');
    });
    test('hyp + SHIFT + cos', () {
      expect(press('hyp SHIFT cos').upper, 'cosh⁻¹ ');
    });
  });

  group('hyp', () {
    test('shows the hyp indicator until a key uses it', () {
      expect(press('hyp').indicators, contains(Indicator.hyp));
      expect(press('sin').indicators, isNot(contains(Indicator.hyp)));
    });
    test('hyp twice cancels', () {
      expect(press('hyp hyp').indicators, isNot(contains(Indicator.hyp)));
    });
    test('hyp before a non-trig key is dropped', () {
      expect(press('hyp 5').upper, '5');
    });
  });

  group('Ran#', () {
    test('gives 3-digit values in [0, 0.999]', () {
      final d = press('Ran# =');
      final v = double.parse(d.lower);
      expect(v, inInclusiveRange(0, 0.999));
      expect(
        d.lower.replaceFirst(RegExp(r'^0?\.'), '').length,
        lessThanOrEqualTo(3),
      );
    });
    test('= gives a new value each time', () {
      final seen = <String>{};
      press('1000 Ran# =');
      for (var i = 0; i < 5; i++) {
        seen.add(press('=').lower);
      }
      expect(seen.length, greaterThan(1));
    });
  });

  group('errors', () {
    test('tan 90 (Deg) → Math ERROR', () {
      expect(press('tan 90 =').upper, 'Math ERROR');
    });
    test('x! of 70 → Math ERROR', () {
      expect(press('70 fact =').upper, 'Math ERROR');
    });
  });

  group('MODE menus', () {
    test('first MODE press shows the calculation mode menu', () {
      final d = press('MODE');
      expect(d.upper, 'COMP CMPLX');
      expect(d.menuMarks, {1: '1', 7: '2'});
      expect(d.lower, '');
    });
    test('MODE steps through 6 screens, then returns to calculation', () {
      press('7 +');
      expect(press('MODE MODE').upper, 'SD REG BASE');
      expect(press('MODE').upper, 'EQN MAT VCT');
      expect(press('MODE').upper, 'Deg Rad Gra');
      expect(press('MODE').upper, 'Fix Sci Norm');
      expect(press('MODE').upper, 'Disp');
      final d = press('MODE');
      expect(d.upper, '7+');
      expect(d.menuMarks, isNull);
    });
    test('angle unit selection updates the indicator', () {
      expect(press(rad).indicators, contains(Indicator.rad));
      expect(press(gra).indicators, contains(Indicator.gra));
    });
    test('AC closes a menu without changes', () {
      final d = press('MODE MODE MODE MODE AC');
      expect(d.indicators, contains(Indicator.deg));
      expect(d.upper, '');
    });
    test('menus keep the expression being edited', () {
      press('1 + 2 $rad');
      expect(calc.display.upper, '1+2');
      vector('=', '3.');
    });
    test('Fix prompt then digit sets Fix with indicator', () {
      expect(press('MODE MODE MODE MODE MODE 1').upper, 'Fix 0~9?');
      final d = press('2');
      expect(d.indicators, contains(Indicator.fix));
      vector('100 ÷ 7 =', '14.29');
    });
    test('Sci 2', () {
      press('MODE MODE MODE MODE MODE 2 2');
      expect(calc.display.indicators, contains(Indicator.sci));
      vector('1 ÷ 3 =', '3.3', '-01');
    });
    test('Norm 2', () {
      press('MODE MODE MODE MODE MODE 3 2');
      vector('1 ÷ 200 =', '0.005');
    });
    test('Norm prompt ignores digits other than 1 and 2', () {
      expect(press('MODE MODE MODE MODE MODE 3 5').upper, 'Norm 1~2?');
    });
    test('changing display format re-formats a shown result', () {
      press('100 ÷ 7 =');
      press('MODE MODE MODE MODE MODE 1 3');
      expect(calc.display.lower, '14.286');
    });
    test('unimplemented mode choices are ignored', () {
      expect(press('MODE MODE MODE MODE MODE MODE 2').upper, 'Disp');
    });
    test('COMP closes the menu', () {
      expect(press('MODE 1').upper, '');
    });
  });

  group('DRG▶ menu', () {
    test('shows D R G with 1 2 3 marks', () {
      final d = press('DRG');
      expect(d.upper, ' D   R   G');
      expect(d.menuMarks, {1: '1', 5: '2', 9: '3'});
    });
    test('converts grads to degrees', () => vector('100 DRG 3 =', '90.'));
    test('AC cancels', () => expect(press('DRG AC').upper, ''));
  });
}
