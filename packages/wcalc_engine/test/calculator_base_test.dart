import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'support/keys.dart';

void main() {
  late Calculator calc;

  setUp(
    () => calc = Calculator()
      ..press(CalcKey.mode)
      ..press(CalcKey.mode)
      ..press(CalcKey.d3),
  );

  DisplayState press(String sequence) {
    keys(sequence).forEach(calc.press);
    return calc.display;
  }

  /// (result line, base letter)
  (String, String?) shown(String sequence) {
    final d = press(sequence);
    return (d.lower, d.engSymbol);
  }

  test('enters BASE in decimal with the d letter', () {
    expect(shown(''), ('0.', 'd'));
  });

  group('manual p.56-58', () {
    test('11 + 1 in binary = 100', () {
      expect(shown('BIN'), ('0.', 'b'));
      expect(shown('11 + 1 ='), ('100.', 'b'));
    });
    test('10d + 10h + 10b + 10o = 36', () {
      press(
        'AC DEC LOGIC LOGIC LOGIC 1 10 + LOGIC LOGIC LOGIC 2 10 + LOGIC LOGIC LOGIC 3 10 + LOGIC LOGIC LOGIC 4 10',
      );
      expect(calc.display.upper, 'h10+b10+o10');
      expect(shown('='), ('36.', 'd'));
    });
    test('15 × 3 = 45 → 2d, 101101, 55', () {
      expect(shown('AC DEC 15 × 3 ='), ('45.', 'd'));
      expect(shown('HEX'), ('2d.', 'h'));
      expect(shown('BIN'), ('101101.', 'b'));
      expect(shown('OCT'), ('55.', 'o'));
    });
    test(
      'binary 10111 + 11010 = 110001',
      () => expect(shown('AC BIN 10111 + 11010 =').$1, '110001.'),
    );
    test('octal 7 + 1 = 10', () => expect(shown('AC OCT 7 + 1 =').$1, '10.'));
    test('hex 1F + 1 = 20', () => expect(shown('AC HEX 1 hF + 1 =').$1, '20.'));
    test('30 → 11110, 36, 1E', () {
      press('AC DEC 30 =');
      expect(shown('BIN').$1, '11110.');
      expect(shown('OCT').$1, '36.');
      expect(shown('HEX').$1, '1E.');
    });
    test('5d + 5h in binary = 1010', () {
      expect(
        shown('AC BIN LOGIC LOGIC LOGIC 1 5 + LOGIC LOGIC LOGIC 2 5 =').$1,
        '1010.',
      );
    });
  });

  group('logic (manual p.58-59)', () {
    setUp(() => press('BIN'));
    test('and', () => expect(shown('AC 1010 LOGIC 1 1100 =').$1, '1000.'));
    test('or', () => expect(shown('AC 1011 LOGIC 2 11010 =').$1, '11011.'));
    test('xor', () => expect(shown('AC 1010 LOGIC LOGIC 1 1100 =').$1, '110.'));
    test(
      'xnor',
      () => expect(shown('AC 1111 LOGIC 3 101 =').$1, '1111110101.'),
    );
    test(
      'Not',
      () => expect(shown('AC LOGIC LOGIC 2 1010 =').$1, '1111110101.'),
    );
    test(
      'Neg',
      () => expect(shown('AC LOGIC LOGIC 3 101101 =').$1, '1111010011.'),
    );
    test('menus', () {
      expect(press('AC LOGIC').upper, 'And Or Xnor');
      expect(press('LOGIC').upper, 'Xor Not Neg');
      expect(press('LOGIC').upper, ' d  h  b  o');
      press('AC');
    });
    test('logic operators bind looser than +', () {
      expect(shown('AC 1 + 1 LOGIC 2 1 =').$1, '11.');
    });
  });

  group('integer rules and ranges', () {
    test('division truncates', () => expect(shown('AC DEC 7 ÷ 2 =').$1, '3.'));
    test('negative decimal', () => expect(shown('AC DEC 3 - 5 =').$1, '-2.'));
    test('negative shown as two\'s complement in hex', () {
      press('AC DEC 3 - 5 =');
      expect(shown('HEX').$1, 'FFFFFFFE.');
    });
    test('out of 10-bit binary range → Math ERROR', () {
      press('AC DEC 600 =');
      expect(press('BIN').upper, 'Math ERROR');
    });
    test('32-bit overflow → Math ERROR', () {
      expect(press('AC DEC 2147483647 + 1 =').upper, 'Math ERROR');
    });
    test('binary digits only 0/1', () {
      expect(press('AC BIN 12 =').upper, 'Syntax ERROR');
    });
    test(
      'division by zero',
      () => expect(press('AC DEC 1 ÷ 0 =').upper, 'Math ERROR'),
    );
    test('scientific keys do nothing', () {
      expect(press('AC DEC 2 sin').upper, '2D');
      expect(press('AC DEC 2 √').upper, '2');
    });
    test('negative binary input is two\'s complement', () {
      expect(shown('AC BIN 1111111111 =').$1, '1111111111.');
      expect(shown('DEC').$1, '-1.');
    });
    test('Ans and history keep working', () {
      press('AC DEC 5 = Ans + 1 =');
      expect(calc.display.lower, '6.');
      expect(press('up').upper, '5');
    });
  });
}
