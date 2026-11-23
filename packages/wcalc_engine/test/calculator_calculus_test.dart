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

  const rad = 'MODE MODE MODE MODE 2';

  group('integration (manual p.34)', () {
    test('∫(2X²+3X+8, 1, 5, 6) = 150.6666667', () {
      expect(press('∫dx').upper, '∫(');
      vector('2 X x2 + 3 X + 8 , 1 , 5 , 6 ) =', '150.6666667');
    });
    test('partitions may be omitted', () => vector('∫dx X , 0 , 1 ) =', '0.5'));
    test('∫ sin X from 0 to π (Rad) = 2', () {
      vector('$rad ∫dx sin X , 0 , pi ) =', '2.');
    });
    test(
      'reversed limits change the sign',
      () => vector('∫dx X x2 , 3 , 0 ) =', '-9.'),
    );
    test('integral inside an expression', () {
      vector('1 + ∫dx 2 X , 0 , 1 ) × 3 =', '4.');
    });
    test('does not change X', () {
      press('7 STO kX');
      press('∫dx X , 0 , 1 ) =');
      vector('RCL kX', '7.');
    });
    test('partition count outside 1..9 → Math ERROR', () {
      expect(press('∫dx X , 0 , 1 , 10 ) =').upper, 'Math ERROR');
    });
    test('missing range → Syntax ERROR', () {
      expect(press('AC ∫dx X , 0 ) =').upper, 'Syntax ERROR');
    });
  });

  group('differentiation (manual p.35)', () {
    test('d/dx(3X²-5X+2, 2, 2E-4) = 7', () {
      expect(press('d/dx').upper, 'd/dx(');
      vector('3 X x2 - 5 X + 2 , 2 , 2 EXP (-) 4 ) =', '7.');
    });
    test('Δx may be omitted', () => vector('d/dx X x3 , 2 ) =', '12.'));
    test(
      'd/dx sin X at 0 (Rad) = 1',
      () => vector('$rad d/dx sin X , 0 ) =', '1.'),
    );
    test('d/dx eˣ at 1', () => vector('d/dx e^ X , 1 ) =', '2.718281828'));
    test('missing point → Syntax ERROR', () {
      expect(press('d/dx X ) =').upper, 'Syntax ERROR');
    });
  });

  group('slow-key detection for the busy display', () {
    test('= on an integral is slow, plain arithmetic is not', () {
      press('1 + 1');
      expect(calc.isSlowKey(CalcKey.equals), isFalse);
      press('AC ∫dx X , 0 , 1 )');
      expect(calc.isSlowKey(CalcKey.equals), isTrue);
      expect(calc.isSlowKey(CalcKey.d1), isFalse);
    });
    test('SOLVE is slow', () {
      press('X x2 - 4 SOLVE');
      press('SHIFT');
      expect(calc.isSlowKey(CalcKey.calc), isTrue);
    });
  });
}
