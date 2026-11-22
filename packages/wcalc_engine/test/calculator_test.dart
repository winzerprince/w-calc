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

  /// Asserts the result line after a key sequence (test-vector style).
  void vector(String sequence, String mantissa, [String? exponent]) {
    final d = press(sequence);
    expect((d.lower, d.exponent), (mantissa, exponent), reason: sequence);
  }

  group('initial state', () {
    test('empty input, 0. result, cursor at column 0', () {
      final d = calc.display;
      expect(d.upper, '');
      expect(d.lower, '0.');
      expect(d.exponent, isNull);
      expect(d.cursor, 0);
      expect(d.cursorStyle, CursorStyle.underscore);
      expect(d.indicators, {Indicator.deg}); // Deg is the default angle unit
    });
  });

  group('manual arithmetic examples (keys → result)', () {
    test('23 + 4.5 - 53 = -25.5', () => vector('23 + 4.5 - 53 =', '-25.5'));
    test(
      '56 × (-12) ÷ (-2.5) = 268.8',
      () => vector('56 × ( (-) 12 ) ÷ ( (-) 2.5 ) =', '268.8'),
    );
    test(
      '2 ÷ 3 × 1E20',
      () => vector('2 ÷ 3 × 1 EXP 20 =', '6.666666667', '19'),
    );
    test('7 × 8 - 4 × 5 = 36', () => vector('7 × 8 - 4 × 5 =', '36.'));
    test('6 ÷ (4 × 5) = 0.3', () => vector('6 ÷ ( 4 × 5 ) =', '0.3'));
    test(
      '2 × (7 + 6 × (5 + 4)) = 122',
      () => vector('2 × ( 7 + 6 × ( 5 + 4 ) ) =', '122.'),
    );
    test('(2 + 3) × (4 - 1 = 15', () => vector('( 2 + 3 ) × ( 4 - 1 =', '15.'));
    test('1 ÷ 3 × 3 shows 1.', () => vector('1 ÷ 3 × 3 =', '1.'));
  });

  group('after a result', () {
    test('upper line shows the expression from its start, no cursor', () {
      final d = press('4 × 5 =');
      expect(d.upper, '4×5');
      expect(d.lower, '20.');
      expect(d.cursor, isNull);
    });

    test('operator key continues with Ans', () {
      final d = press('3 × 4 = ÷ 30');
      expect(d.upper, 'Ans÷30');
      expect(press('=').lower, '0.4');
    });

    test('digit key starts a new calculation', () {
      expect(press('1 + 1 = 5').upper, '5');
    });

    test(
      'Ans key recalls the last result',
      () => vector('123 + 456 = 789 - Ans =', '210.'),
    );

    test('= repeats the last expression with the new Ans', () {
      press('2 = × 3 =');
      vector('=', '18.');
    });

    test('previous result stays on the lower line while typing', () {
      expect(press('7 = 1 +').lower, '7.');
    });

    test('AC clears input and shows 0.', () {
      final d = press('7 = AC');
      expect((d.upper, d.lower), ('', '0.'));
    });

    test('Ans survives AC', () => vector('7 = AC Ans + 1 =', '8.'));
  });

  group('editing', () {
    test('replay: ◀ edits the previous expression (manual p.28)', () {
      vector('4 × 3 + 2 =', '14.');
      vector('< DEL DEL - 7 =', '5.');
    });

    test('▶ after a result puts the cursor at the start', () {
      final d = press('12 + 3 = >');
      expect(d.cursor, 0);
      expect(d.upper, '12+3');
    });

    test('DEL removes the token under the cursor (manual p.17 example 2)', () {
      press('369 × × 2 < <');
      expect(calc.display.cursor, 4);
      expect(press('DEL').upper, '369×2');
      vector('=', '738.');
    });

    test('typing in overwrite mode replaces the token under the cursor', () {
      expect(press('1 2 3 < < 9').upper, '193');
    });

    test('INS inserts before the cursor and shows the insert cursor', () {
      press('2 3 6 < <');
      expect(press('INS').cursorStyle, CursorStyle.insert);
      expect(press('1').upper, '2136');
      expect(calc.display.cursor, 2);
    });

    test('INS again returns to overwrite', () {
      expect(press('1 < INS INS').cursorStyle, CursorStyle.underscore);
    });

    test('= leaves insert mode', () {
      press('1 INS =');
      expect(press('<').cursorStyle, CursorStyle.underscore);
    });

    test('DEL in insert mode deletes the token left of the cursor', () {
      expect(press('1 2 3 < INS DEL').upper, '13');
    });

    test('cursor stops at both ends', () {
      press('1 2 < < < <');
      expect(calc.display.cursor, 0);
      press('> > > > >');
      expect(calc.display.cursor, 2);
    });

    test('cursor moves by whole tokens ("Ans" is one step)', () {
      press('5 = + Ans');
      // "Ans+Ans": cursor at end (col 7); one ◀ lands on the second Ans (col 4).
      expect(press('<').cursor, 4);
    });

    test('AC during input clears everything', () {
      expect(press('1 + 2 AC').upper, '');
    });
  });

  group('errors', () {
    test('Math ERROR screen', () {
      final d = press('1 ÷ 0 =');
      expect(d.upper, 'Math ERROR');
      expect(d.lower, '');
      expect(d.cursor, isNull);
    });

    test('Syntax ERROR screen', () {
      expect(press('2 + =').upper, 'Syntax ERROR');
    });

    test('◀ returns to the expression with the cursor at the error', () {
      press('1 ÷ 0 =');
      final d = press('<');
      expect(d.upper, '1÷0');
      expect(d.cursor, 1);
    });

    test('AC clears the error and the expression', () {
      expect(press('1 ÷ 0 = AC').upper, '');
    });

    test('other keys are ignored on the error screen', () {
      expect(press('1 ÷ 0 = 5').upper, 'Math ERROR');
    });

    test(
      'Ans is unchanged by an error',
      () => vector('6 = 1 ÷ 0 = AC Ans =', '6.'),
    );
  });

  group('upper line window (12 columns)', () {
    test('long input scrolls so the cursor stays visible', () {
      final d = press('123456789012345');
      expect(d.upper, '56789012345');
      expect(d.cursor, 11);
    });

    test('moving left past the window start scrolls back', () {
      press('123456789012345');
      for (var i = 0; i < 12; i++) {
        calc.press(CalcKey.left);
      }
      expect(calc.display.cursor, 0);
      expect(calc.display.upper, '456789012345');
    });

    test('after = the window shows the start', () {
      expect(press('123456789012345 =').upper, '123456789012');
    });
  });

  group('79-step limit', () {
    test('cursor becomes a block from the 73rd step', () {
      press('1' * 72);
      expect(calc.display.cursorStyle, CursorStyle.underscore);
      press('1');
      expect(calc.display.cursorStyle, CursorStyle.block);
    });

    test('input beyond 79 steps is ignored', () {
      press('1' * 85);
      press('=');
      calc.press(CalcKey.left);
      // 79 ones: value 1.111111111e78
      expect(press('=').exponent, '78');
    });
  });

  group('modifiers', () {
    test('SHIFT shows S and is consumed by the next key', () {
      expect(press('SHIFT').indicators, contains(Indicator.shift));
      expect(press('1').indicators, {Indicator.deg});
    });

    test('SHIFT twice cancels', () {
      expect(press('SHIFT SHIFT').indicators, {Indicator.deg});
    });

    test('ALPHA replaces SHIFT; ALPHA twice cancels', () {
      expect(press('SHIFT ALPHA').indicators, {Indicator.alpha, Indicator.deg});
      expect(press('ALPHA').indicators, {Indicator.deg});
    });

    test('unassigned shifted key does nothing', () {
      expect(press('1 SHIFT 2').upper, '1');
    });
  });

  test('DisplayState has a readable toString', () {
    expect(calc.display.toString(), contains('0.'));
  });
}
