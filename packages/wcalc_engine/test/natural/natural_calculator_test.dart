import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Key names for the textbook keypad (on top of the shared ones).
const _extra = {
  'S<>D': CalcKey.sd,
  'frac': CalcKey.fraction,
  'logb': CalcKey.logBase,
};

List<CalcKey> keys(String s) => [
  for (final w in s.trim().split(RegExp(r'\s+')))
    if (_extra.containsKey(w)) _extra[w]! else ...parseKeySequence(w),
];

void main() {
  late NaturalCalculator calc;
  setUp(() => calc = NaturalCalculator(random: math.Random(1)));

  String press(String s) {
    keys(s).forEach(calc.press);
    return calc.screen.text;
  }

  String result(String s) {
    final t = press(s);
    final i = t.lastIndexOf(' = ');
    return i < 0 ? t : t.substring(i + 3);
  }

  group('COMP basics (Math display)', () {
    test('4 × sin(30) × (30 + 10 × 3) = 120', () {
      expect(result('4 × sin 30 ) × ( 30 + 10 × 3 ) ='), '120');
    });
    test('closing parentheses may be omitted: 4 sin 30 ) ( 30 + 10 × 3 =', () {
      expect(result('4 sin 30 ) ( 30 + 10 × 3 ='), '120');
    });
    test('2/3 + 1/2 = 7/6 shown as a fraction', () {
      expect(result('2 frac 3 > + 1 frac 2 ='), 'fraction{7|6}');
    });
    test('S⇔D toggles to the decimal', () {
      press('2 frac 3 > + 1 frac 2 =');
      expect(result('S<>D'), '1.166666667');
      expect(result('S<>D'), 'fraction{7|6}');
    });
    test('SHIFT = gives the decimal directly', () {
      expect(result('1 ÷ 3 SHIFT ='), '0.3333333333');
    });
    test('mixed fraction with SHIFT S⇔D (ab/c ⇔ d/c)', () {
      press('2 frac 3 > + 1 frac 2 =');
      expect(result('SHIFT S<>D'), 'mixed{1|1|6}');
    });
    test('0.5 shows as 1/2 on the Math display', () {
      expect(result('0.5 ='), 'fraction{1|2}');
    });
    test('integers show without a decimal point', () {
      expect(result('3 + 4 ='), '7');
    });
    test('operator after a result continues from Ans', () {
      press('3 × 4 =');
      expect(result('÷ 30 ='), 'fraction{2|5}');
    });
    test('Ans memory: 123 + 456 then 789 − Ans = 210', () {
      press('123 + 456 =');
      expect(result('789 - Ans ='), '210');
    });
    test('large results use ×10 with a raised exponent', () {
      expect(result('2 EXP 20 × 3 ='), '6×tenPow{20}');
    });
  });

  group('Linear display', () {
    setUp(() => press('SHIFT MODE 2'));
    test('fractions shown as 7⌟6 after S⇔D; decimals first', () {
      expect(result('2 frac 3 + 1 frac 2 ='), '1.166666667');
      expect(result('S<>D'), '7⌟6');
    });
    test('Math indicator is off', () {
      expect(calc.screen.indicators, isNot(contains(Indicator.math)));
    });
  });

  group('memories', () {
    test('STO A, ALPHA A × 10, RCL A', () {
      press('3 + 5 SHIFT RCL (-)');
      expect(calc.variables['A']!.dec, Dec.fromInt(8));
      expect(result('AC ALPHA (-) × 10 ='), '80');
      expect(result('RCL (-)'), '8');
    });
    test('M+ and M− with the M indicator', () {
      press('0 SHIFT RCL M+');
      press('10 × 5 M+');
      press('10 + 5 SHIFT M+');
      expect(calc.variables['M']!.dec, Dec.fromInt(35));
      expect(calc.screen.indicators, contains(Indicator.memory));
    });
  });

  group('errors', () {
    test('14 ÷ 0 × 2 = Math ERROR, ◀ goes to the problem', () {
      expect(press('14 ÷ 0 × 2 ='), startsWith('Math ERROR'));
      press('<');
      expect(calc.screen.text, isNot(contains('ERROR')));
    });
    test('AC clears the error and the calculation', () {
      press('1 + =');
      expect(calc.screen.text, startsWith('Syntax ERROR'));
      expect(press('AC'), '');
    });
  });

  group('menus', () {
    test('MODE shows the 8 modes', () {
      expect(press('MODE'), contains('1:COMP  2:CMPLX'));
      expect(calc.screen.text, contains('7:TABLE 8:VECTOR'));
    });
    test('SETUP Fix 3: 100 ÷ 7 = 14.286', () {
      press('SHIFT MODE 6 3');
      expect(calc.screen.indicators, contains(Indicator.fix));
      expect(result('100 ÷ 7 SHIFT ='), '14.286');
    });
    test('SETUP page 2 via ▼', () {
      expect(press('SHIFT MODE down'), contains('1:ab/c  2:d/c'));
    });
    test('CLR All asks for confirmation', () {
      press('5 SHIFT RCL (-)');
      expect(press('SHIFT 9 3'), contains('Reset All?'));
      press('=');
      expect(calc.variables['A']!.dec, Dec.zero);
    });
    test('hyp menu: sinh 1 = 1.175201194', () {
      expect(result('hyp 1 1 ) ='), '1.175201194');
    });
  });

  group('functions', () {
    test('log_2 16 = 4 with the log_□ key', () {
      expect(result('logb 2 > 16 ='), '4');
    });
    test('Σ(X+1, 1, 5) = 20', () {
      expect(result('SHIFT logb ALPHA ) + 1 > 1 > 5 ='), '20');
    });
    test('150 × 20 % = 30', () {
      expect(result('150 × 20 SHIFT ( ='), '30');
    });
    test('nPr / nCr', () {
      expect(result('10 SHIFT × 4 ='), '5040');
      expect(result('10 SHIFT ÷ 4 ='), '210');
    });
    test('Pol(√2, √2) stores r, θ in X, Y', () {
      press('SHIFT + √ 2 > SHIFT ) √ 2 > ) =');
      double v(String n) => double.parse(calc.variables[n]!.dec.toString());
      expect(v('X'), closeTo(2, 1e-12));
      expect(v('Y'), closeTo(45, 1e-12));
    });
  });

  test('OFF blanks the screen until ON; memories kept', () {
    press('7 SHIFT RCL (-)');
    press('SHIFT AC');
    expect(calc.screen.isOff, isTrue);
    press('ON');
    expect(calc.screen.isOff, isFalse);
    expect(calc.variables['A']!.dec, Dec.fromInt(7));
  });

  test('state round-trips', () {
    press('SHIFT MODE 4 9 SHIFT RCL (-)');
    final other = NaturalCalculator()..restoreState(calc.saveState());
    expect(other.angle, AngleUnit.rad);
    expect(other.variables['A']!.dec, Dec.fromInt(9));
  });
}
