import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Broader behaviour of the textbook calculator: Linear entry, menus,
/// prompts, history, editors and navigation.
void main() {
  late NaturalCalculator c;
  setUp(() => c = NaturalCalculator(random: math.Random(3)));

  String press(String keys) {
    for (final k in parseKeySequence(keys)) {
      c.press(k);
    }
    return c.screen.text;
  }

  String result(String keys) {
    final t = press(keys);
    final i = t.lastIndexOf(' = ');
    return i < 0 ? t : t.substring(i + 3);
  }

  group('Linear display entry', () {
    setUp(() => press('SHIFT MODE 2'));
    test('fraction, power, root and log in one line', () {
      expect(result('1 frac 4 + 2 ^ 3 ) ='), '8.25');
      expect(result('AC 3 SHIFT ^ 8 ) ='), '2');
      expect(result('AC logb 2 SHIFT ) 8 ) ='), '3');
    });
    test('Σ, d/dx, ∫ and Abs use bracket syntax', () {
      expect(result('AC SHIFT logb ALPHA ) SHIFT ) 1 SHIFT ) 3 ) ='), '6');
      expect(result('AC SHIFT ∫dx ALPHA ) x2 SHIFT ) 2 ) ='), '4');
      expect(result('AC ∫dx ALPHA ) SHIFT ) 0 SHIFT ) 2 ) ='), '2');
      expect(result('AC SHIFT hyp (-) 3 ) ='), '3');
    });
    test('SHIFT DEL switches to overwrite', () {
      press('AC 123 < < SHIFT DEL 9');
      expect(result('='), '193');
    });
    test('mixed-fraction key types the fraction mark', () {
      expect(result('AC SHIFT MODE down 1 1 SHIFT frac 1 frac 2 ='), '1.5');
    });
  });

  group('keys and menus', () {
    test('cos, tan⁻¹, x!, Rec, x^ template', () {
      expect(result('cos 60 ) ='), 'fraction{1|2}');
      expect(result('SHIFT tan 1 ) ='), '45');
      expect(result('4 SHIFT x-1 ='), '24');
      expect(result('SHIFT - 2 SHIFT ) 60 ) ='), '1');
      expect(result('2 ^ 10 ='), '1024');
    });
    test('CONST and CONV prompts', () {
      expect(press('SHIFT 7'), startsWith('CONST'));
      expect(result('28 ='), '299792458');
      expect(result('100 SHIFT 8 22 SHIFT ='), '3.527396195');
      press('SHIFT 7 AC');
      expect(c.screen.text, isNot(startsWith('CONST')));
    });
    test('DRG menu converts the angle unit', () {
      expect(result('SHIFT MODE 4 180 SHIFT Ans 1 ='), 'π');
    });
    test('ENG both ways and back to normal', () {
      expect(result('1234 = ENG'), '1.234×tenPow{3}');
      expect(result('SHIFT ENG'), '0.001234×tenPow{6}');
      expect(result('S<>D'), '1234');
    });
    test('ALPHA e, :, RanInt', () {
      expect(result('ALPHA EXP ='), '2.718281828');
      final r = result('ALPHA . 1 SHIFT ) 6 ) =');
      expect(int.parse(r), inInclusiveRange(1, 6));
    });
    test('history ▲ ▼ and replay ◀', () {
      press('1 + 1 = 2 + 2 = 3 + 3 =');
      expect(result('up'), '4');
      expect(result('up'), '2');
      expect(result('down'), '4');
      press('<');
      expect(c.screen.text, startsWith('2+2'));
    });
    test('DEL after a result edits it; contrast and hyp inverses', () {
      press('12 + 3 = DEL DEL 4 =');
      expect(c.ans.dec, Dec.fromInt(16));
      press('SHIFT MODE down 6 > > AC');
      expect(c.contrast, 2);
      expect(result('hyp 4 0 ) ='), '0');
    });
    test('CLR Setup keeps memories; Memory clears them', () {
      press('5 SHIFT RCL (-) SHIFT MODE 4');
      press('SHIFT 9 1 =');
      expect(c.angle, AngleUnit.deg);
      expect(c.variables['A']!.dec, Dec.fromInt(5));
      press('SHIFT 9 2 =');
      expect(c.variables['A']!.dec, Dec.zero);
      press('SHIFT 9 3 AC');
      expect(c.screen.text, isNot(contains('Reset')));
    });
    test('Disp Comma and complex polar setup', () {
      press('SHIFT MODE down 5 2');
      expect(result('1 ÷ 4 SHIFT ='), '0,25');
      press('SHIFT MODE down 3 2 MODE 2');
      expect(result('1 + ENG ='), contains('∠'));
    });
  });

  group('editors', () {
    test('matrix grid navigation, Data and mismatched Data', () {
      press('MODE 6 1 5 1 = 2 = 3 = 4 = up < > down AC');
      press('SHIFT 4 2 1');
      expect(c.screen.text, startsWith('MatA'));
      press('AC SHIFT 4 2 2');
      expect(c.screen.text, startsWith('Dimension ERROR'));
    });
    test('matrix size page two and vector D', () {
      press('MODE 6 1 down 8');
      expect(c.linearVariables['MatA'].toString(), contains('Value'));
      final big = NaturalCalculator(bigLinear: true);
      for (final k in parseKeySequence(
        'MODE 8 4 1 1 = 2 = 3 = AC SHIFT 5 down 9 =',
      )) {
        big.press(k);
      }
      expect(big.screen.text, startsWith('VctAns'));
    });
    test('EQN editor navigation and a bad coefficient', () {
      press('MODE 5 1 down up > < 1 ÷ 0 =');
      expect(c.screen.text, startsWith('Math ERROR'));
    });
    test('table prompts: typing, DEL, AC and an empty range', () {
      press('MODE 7 ALPHA ) = 1 2 DEL = AC');
      expect(c.screen.text, isNot(startsWith('End?')));
      press('= 5 = 1 = 1 =');
      expect(c.screen.text, startsWith('Math ERROR'));
    });
    test('table scrolls and a row with an undefined value shows ERROR', () {
      press('MODE 7 1 ÷ ALPHA ) = (-) 1 = 1 = 1 =');
      expect(c.screen.text, contains('ERROR'));
      press('down down up > <');
      expect(c.screen.text, startsWith('TABLE'));
    });
    test('SOLVE start values can be stepped with ▲ ▼', () {
      press('ALPHA ) x2 - 4 SHIFT CALC up down 3 . 5 =');
      expect(c.screen.text, contains('X= 2'));
    });
  });

  test('graphable expressions', () {
    expect(c.graphTokens, isNull);
    press('ALPHA ) x2 + 1');
    expect(c.graphTokens, isNotNull);
    expect(c.angleUnit, AngleUnit.deg);
  });

  test('menu rows: ◀ ▶ move the highlight, = chooses', () {
    final v = NaturalCalculator(
      menuCursor: true,
      modes: {NaturalMode.comp, NaturalMode.stat, NaturalMode.table},
    );
    for (final k in parseKeySequence('MODE > =')) {
      v.press(k);
    }
    expect(v.mode, NaturalMode.stat);
    for (final k in parseKeySequence('AC MODE < =')) {
      v.press(k);
    }
    expect(v.mode, NaturalMode.table);
    // Numbers still choose directly.
    for (final k in parseKeySequence('AC MODE 1')) {
      v.press(k);
    }
    expect(v.mode, NaturalMode.comp);
    for (final k in parseKeySequence('MODE')) {
      v.press(k);
    }
    expect(v.screen.dots.toAscii().contains('#'), isTrue);
  });
}
