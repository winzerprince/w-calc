import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Key names for the textbook keypad (on top of the shared ones).
const _extra = <String, CalcKey>{
  'x^': CalcKey.power,
  'sd': CalcKey.sd,
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

  group('exact √ and π forms (Math display)', () {
    test('√2 + √2 = 2√2', () {
      expect(result('√ 2 > + √ 2 ='), '2sqrt{2}');
    });
    test('(√2 + 2) × √3 = 2√3 + √6, S⇔D gives 5.913591358', () {
      expect(result('( √ 2 > + 2 ) × √ 3 ='), '2sqrt{3}+sqrt{6}');
      expect(result('S<>D'), '5.913591358');
    });
    test('π ÷ 6 = π/6; SHIFT = gives 0.5235987756, S⇔D back to π/6', () {
      expect(result('SHIFT EXP ÷ 6 ='), 'fraction{π|6}');
      expect(result('AC SHIFT EXP ÷ 6 SHIFT ='), '0.5235987756');
      expect(result('S<>D'), 'fraction{π|6}');
    });
    test('sin 45° = √2/2 (recognised)', () {
      expect(result('sin 45 ) ='), 'fraction{sqrt{2}|2}');
    });
    test('1 ÷ √2 = √2/2', () {
      expect(result('1 ÷ √ 2 ='), 'fraction{sqrt{2}|2}');
    });
    test('(1 + √5) ÷ 2 keeps the sum form', () {
      expect(result('frac 1 + √ 5 > down 2 ='), 'fraction{1+sqrt{5}|2}');
    });
    test('−√3 shows the minus in front', () {
      expect(result('(-) √ 3 ='), '-sqrt{3}');
    });
    test('Rad: sin⁻¹ 1 = π/2', () {
      press('SHIFT MODE 4');
      expect(result('SHIFT sin 1 ) ='), 'fraction{π|2}');
    });
    test('decimals typed are exact: 0.5 + 0.25 = 3/4', () {
      expect(result('0.5 + 0.25 ='), 'fraction{3|4}');
    });
    test('2π stays a π form, π² falls back to a decimal', () {
      expect(result('2 SHIFT EXP ='), '2π');
      expect(result('SHIFT EXP x2 ='), '9.869604401');
    });
    test('SHIFT = then S⇔D does not offer √ forms', () {
      press('√ 2 > SHIFT =');
      expect(result('S<>D'), '1.414213562');
    });
    test('Linear display: √2 stays decimal; S⇔D has no √ form', () {
      press('SHIFT MODE 2');
      expect(result('√ 2 ) ='), '1.414213562');
      expect(result('S<>D'), '1.414213562');
    });
  });

  group('CMPLX', () {
    setUp(() => press('MODE 2'));
    test('(2 + 6i) ÷ (2i) = 3 − i', () {
      expect(result('( 2 + 6 ENG ) ÷ ( 2 ENG ) ='), '3-i');
      expect(calc.screen.indicators, contains(Indicator.cmplx));
    });
    test('(1 − i)⁻¹ = 1/2 + 1/2 i', () {
      expect(result('( 1 - ENG ) x-1 ='), 'fraction{1|2}+fraction{1|2}i');
    });
    test('(1 + i)² + (1 − i)² = 0', () {
      expect(result('( 1 + ENG ) x2 + ( 1 - ENG ) x2 ='), '0');
    });
    test('√2 + √2 i = 2∠45 with ▶r∠θ', () {
      expect(result('√ 2 > + √ 2 > ENG SHIFT 2 3 ='), '2∠45');
    });
    test('2∠45 ▶a+bi = √2 + √2 i', () {
      expect(result('2 SHIFT (-) 45 SHIFT 2 4 ='), 'sqrt{2}+sqrt{2}i');
    });
    test('Conjg(2 + 3i) = 2 − 3i', () {
      expect(result('SHIFT 2 2 2 + 3 ENG ) ='), '2-3i');
    });
  });

  group('CALC', () {
    test('3A + B for (A, B) = (5, 10) then (7, 20)', () {
      press('3 ALPHA (-) + ALPHA °′″ CALC');
      expect(calc.screen.text, startsWith('A?'));
      press('5 = 10 =');
      expect(result(''), '25');
      press('CALC 7 = 20 =');
      expect(result(''), '41');
    });
    test('Y = X² + X + 3 stores into Y', () {
      press('ALPHA sd ALPHA CALC ALPHA ) x2 + ALPHA ) + 3 CALC 2 =');
      expect(calc.variables['Y']!.dec, Dec.fromInt(9));
    });
  });

  group('SOLVE', () {
    test('Y = AX² + B for Y = 0, A = 1, B = −2 from X = 1: X = √2', () {
      press('ALPHA sd ALPHA CALC ALPHA (-) ALPHA ) x2 + ALPHA °′″ SHIFT CALC');
      expect(calc.screen.text, startsWith('Y?'));
      press('0 = 1 = (-) 2 =');
      expect(calc.screen.text, contains('Solve for X'));
      press('1 =');
      expect(calc.screen.text, contains('X= 1.414213562'));
      // L−R is 0 or a last-digit rounding remainder (behaviour note #79).
      expect(calc.screen.text, matches(RegExp(r'L-R= (0|-?1×10\^-1[45])$')));
    });
    test('no X: Variable ERROR', () {
      press('ALPHA (-) + 1 SHIFT CALC');
      expect(calc.screen.text, startsWith('Variable ERROR'));
    });
  });

  group('STAT', () {
    test('MODE 3 shows the type menu; 1-VAR opens the editor', () {
      expect(press('MODE 3'), contains('1:1-VAR  2:A+BX'));
      expect(press('1'), startsWith('STAT X'));
      expect(calc.screen.indicators, contains(Indicator.stat));
      expect(calc.screen.indicators, isNot(contains(Indicator.math)));
    });
    test('1-VAR with FREQ: mean 3, σx 1.154700538', () {
      press('SHIFT MODE down 4 1'); // FREQ column on
      press('MODE 3 1');
      press('1 = 2 = 3 = 4 = 5 =');
      press('up up up up up >');
      press('1 = 2 = 3 = 2 = 1 =');
      expect(calc.statItems, hasLength(5));
      expect(result('AC SHIFT 1 4 2 ='), '3');
      expect(result('AC SHIFT 1 4 3 ='), '1.154700538');
    });
    test('linear and log regression (Fix 3)', () {
      press('SHIFT MODE 6 3');
      press('MODE 3 2');
      press('20 = 110 = 200 = 290 =');
      press('up up up up >');
      press('3150 = 7310 = 8800 = 9310 =');
      expect(result('AC SHIFT 1 5 3 ='), '0.923');
      press('SHIFT 1 1 4'); // ln X keeps paired data
      expect(result('AC SHIFT 1 5 3 ='), '0.998');
      expect(result('AC SHIFT 1 5 1 ='), '-3857.984');
      expect(result('AC SHIFT 1 5 2 ='), '2357.532');
      expect(result('AC 160 SHIFT 1 5 5 ='), '8106.898');
    });
    test('normal distribution: ▶t of 3 and P(t)', () {
      press('SHIFT MODE down 4 1');
      press('SHIFT MODE 6 3');
      press('MODE 3 1');
      press('0 = 1 = 2 = 3 = 4 = 5 = 6 = 7 = 9 = 10 =');
      for (var i = 0; i < 10; i++) {
        press('up');
      }
      press('> 1 = 2 = 1 = 2 = 2 = 2 = 3 = 4 = 2 = 1 =');
      expect(result('AC 3 SHIFT 1 5 4 ='), '-0.762');
      expect(result('SHIFT 1 5 1 Ans ) ='), '0.223');
    });
    test('DEL deletes a row; Edit ▸ Del-A clears all', () {
      press('MODE 3 1 1 = 2 = 3 = up DEL');
      expect(calc.statItems.map((i) => i.x.toString()), ['1', '2']);
      press('SHIFT 1 3 2');
      expect(calc.statItems, isEmpty);
    });
    test('leaving STAT deletes the data', () {
      press('MODE 3 1 5 = AC MODE 1 MODE 3 1');
      expect(calc.statItems, isEmpty);
    });
  });

  group('EQN', () {
    String sol() {
      final t = calc.screen.text;
      return t.substring(t.indexOf('= ') + 2);
    }

    test('x + 2y = 3, 2x + 3y = 4: X = −1, Y = 2', () {
      expect(press('MODE 5'), contains('1:anX+bnY=cn'));
      press('1 1 = 2 = 3 = 2 = 3 = 4 = =');
      expect(calc.screen.text, 'X= -1');
      press('down');
      expect(calc.screen.text, 'Y= 2');
    });
    test('three unknowns: 1, 2, 3', () {
      press('MODE 5 2');
      press('1 = (-) 1 = 1 = 2 = 1 = 1 = (-) 1 = 0 = (-) 1 = 1 = 1 = 4 = =');
      expect(sol(), '1');
      press('down');
      expect(sol(), '2');
      press('down');
      expect(sol(), '3');
    });
    test('x² + x + 3/4: X1 = −1/2 + √2/2 i', () {
      press('MODE 5 3 1 = 1 = 3 frac 4 = =');
      expect(calc.screen.text, 'X1= -fraction{1|2}+fraction{sqrt{2}|2}i');
      press('down');
      expect(calc.screen.text, 'X2= -fraction{1|2}-fraction{sqrt{2}|2}i');
    });
    test('x² − 2√2 x + 2: single root X = √2', () {
      press('MODE 5 3 1 = (-) 2 √ 2 > = 2 = =');
      expect(calc.screen.text, 'X= sqrt{2}');
    });
    test('x³ − 2x² − x + 2: −1, 2, 1', () {
      press('MODE 5 4 1 = (-) 2 = (-) 1 = 2 = =');
      expect(sol(), '-1');
      press('=');
      expect(sol(), '2');
      press('=');
      expect(sol(), '1');
      press('='); // back to the Coefficient Editor
      expect(calc.screen.text, startsWith('EQN cubic'));
    });
    test('AC clears the coefficients', () {
      press('MODE 5 3 5 = AC');
      expect(calc.screen.text, contains('| 0 0 0'));
    });
  });

  group('TABLE', () {
    test('f(X) = X² + 1/2 from −1 to 1 step 0.5', () {
      press('MODE 7 ALPHA ) x2 + 1 frac 2 =');
      expect(calc.screen.text, startsWith('Start? 1'));
      press('(-) 1 = 1 = 0.5 =');
      expect(
        calc.screen.text,
        'TABLE | -1 1.5 | -0.5 0.75 | 0 0.5 | 0.5 0.75 | 1 1.5',
      );
      press('AC');
      expect(calc.screen.text, isNot(startsWith('TABLE')));
    });
    test('more than 30 rows: Insufficient MEM', () {
      press('MODE 7 ALPHA ) = 1 = 100 = 1 =');
      expect(calc.screen.text, startsWith('Insufficient MEM'));
    });
    test('defaults 1..5 step 1', () {
      press('MODE 7 ALPHA ) x2 = = = =');
      expect(calc.screen.text, 'TABLE | 1 1 | 2 4 | 3 9 | 4 16 | 5 25');
    });
  });

  group('BASE-N', () {
    setUp(() => press('MODE 4'));
    test('binary 11 + 1 = 100 (16 digits)', () {
      expect(result('log 11 + 1 ='), '0000000000000100 [Bin]');
    });
    test('hex 1F + 1 = 20', () {
      expect(result('x^ 1 tan + 1 ='), '00000020 [Hex]');
    });
    test('octal 7 + 1 = 10', () {
      expect(result('ln 7 + 1 ='), '00000000010 [Oct]');
    });
    test('15 × 37 in DEC, shown in HEX / BIN / OCT', () {
      expect(result('x2 15 × 37 ='), '555 [Dec]');
      expect(result('x^'), '0000022B [Hex]');
      expect(result('log'), '0000001000101011 [Bin]');
      expect(result('ln'), '00000001053 [Oct]');
    });
    test('logic in binary: and, or, xor, xnor, Not, Neg', () {
      press('log');
      expect(result('1010 SHIFT 3 1 1100 ='), '0000000000001000 [Bin]');
      expect(result('1011 SHIFT 3 2 11010 ='), '0000000000011011 [Bin]');
      expect(result('1010 SHIFT 3 3 1100 ='), '0000000000000110 [Bin]');
      expect(result('1111 SHIFT 3 4 101 ='), '1111111111110101 [Bin]');
      expect(result('SHIFT 3 5 1010 ) ='), '1111111111110101 [Bin]');
      expect(result('SHIFT 3 6 101101 ) ='), '1111111111010011 [Bin]');
    });
    test('d h b o prefixes: 10d + 10h + 10b + 10o = 36', () {
      press('x2');
      expect(
        result(
          'SHIFT 3 down 1 10 + SHIFT 3 down 2 10 + SHIFT 3 down 3 10 + '
          'SHIFT 3 down 4 10 =',
        ),
        '36 [Dec]',
      );
    });
  });

  group('MATRIX', () {
    const setup =
        'MODE 6 1 5 2 = 1 = 1 = 1 = '
        'SHIFT 4 1 2 5 2 = (-) 1 = (-) 1 = 2 = '
        'SHIFT 4 1 3 4 1 = 0 = (-) 1 = 0 = (-) 1 = 1 = AC';
    setUp(() => press(setup));
    test('editor stored MatA', () {
      expect(calc.linearVariables['MatA'].toString(), contains('2'));
      expect(calc.screen.indicators, contains(Indicator.mat));
    });
    test('MatA × MatB and MatA + MatB', () {
      expect(press('SHIFT 4 3 × SHIFT 4 4 ='), 'MatAns | 3 0 | 1 1');
      expect(press('AC SHIFT 4 3 + SHIFT 4 4 ='), 'MatAns | 4 0 | 0 3');
    });
    test('3 × MatA, det, Trn, inverse, Abs, square, cube', () {
      expect(press('3 × SHIFT 4 3 ='), 'MatAns | 6 3 | 3 3');
      expect(result('AC SHIFT 4 7 SHIFT 4 3 ) ='), '1');
      expect(press('AC SHIFT 4 8 SHIFT 4 5 ) ='), 'MatAns | 1 0 | 0 -1 | -1 1');
      expect(press('AC SHIFT 4 3 x-1 ='), 'MatAns | 1 -1 | -1 2');
      expect(press('AC SHIFT hyp SHIFT 4 4 ) ='), 'MatAns | 2 1 | 1 2');
      expect(press('AC SHIFT 4 3 x2 ='), 'MatAns | 5 3 | 3 2');
      expect(press('AC SHIFT 4 3 SHIFT x2 ='), 'MatAns | 13 8 | 8 5');
    });
    test('operator on the MatAns screen continues from MatAns', () {
      press('SHIFT 4 3 + SHIFT 4 4 =');
      expect(press('× 2 ='), 'MatAns | 8 0 | 0 6');
    });
    test('mismatched sizes: Dimension ERROR', () {
      expect(press('SHIFT 4 3 + SHIFT 4 5 ='), startsWith('Dimension ERROR'));
    });
  });

  group('VECTOR', () {
    const setup =
        'MODE 8 1 2 1 = 2 = '
        'SHIFT 5 1 2 2 3 = 4 = '
        'SHIFT 5 1 3 1 2 = (-) 1 = 2 = AC';
    setUp(() => press(setup));
    test('VctA + VctB, 3 × VctA − VctB', () {
      expect(press('SHIFT 5 3 + SHIFT 5 4 ='), 'VctAns | 4 6');
      expect(press('AC 3 × SHIFT 5 3 ='), 'VctAns | 3 6');
      expect(press('- SHIFT 5 4 ='), 'VctAns | 0 2');
    });
    test('dot product 11, cross product, |VctC| = 3', () {
      expect(result('SHIFT 5 3 SHIFT 5 7 SHIFT 5 4 ='), '11');
      expect(press('AC SHIFT 5 3 × SHIFT 5 4 ='), 'VctAns | 0 0 -2');
      expect(result('AC SHIFT hyp SHIFT 5 5 ) ='), '3');
    });
    test('angle between VctA and VctB (Fix 3) = 10.305', () {
      press('SHIFT MODE 6 3');
      press(
        '( SHIFT 5 3 SHIFT 5 7 SHIFT 5 4 ) ÷ ( SHIFT hyp SHIFT 5 3 ) '
        'SHIFT hyp SHIFT 5 4 ) ) =',
      );
      expect(result('SHIFT cos Ans ) ='), '10.305');
    });
  });

  test('mode, STAT data and matrices survive save / restore', () {
    press('MODE 6 1 5 2 = 1 = 1 = 1 = AC');
    press('MODE 3 2 1 = 2 = AC');
    final other = NaturalCalculator()..restoreState(calc.saveState());
    expect(other.mode, NaturalMode.stat);
    expect(other.statType, StatType.lin);
    expect(other.statItems, hasLength(2));
    expect(other.linearVariables.keys, contains('MatA'));
  });

  group('profiles', () {
    test('four-line model lists only its modes', () {
      final c = NaturalCalculator(
        profile: NaturalProfile.multiLine,
        modes: {NaturalMode.comp, NaturalMode.stat, NaturalMode.table},
      );
      c.press(CalcKey.mode);
      expect(c.screen.text, '1:COMP  2:STAT | 3:TABLE');
      c.press(CalcKey.d2);
      expect(c.mode, NaturalMode.stat);
    });
    test('history screen shows the current result', () {
      final c = NaturalCalculator(profile: NaturalProfile.multiLine);
      for (final k in parseKeySequence('1 + 1 = 2 frac 3 > + 1 frac 2 =')) {
        c.press(k);
      }
      expect(c.screen.text, endsWith('= fraction{7|6}'));
      expect(c.screen.dots.toAscii().contains('#'), isTrue);
    });
  });
}
