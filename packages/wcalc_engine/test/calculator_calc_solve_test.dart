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

  (String, String) screen(String sequence) {
    final d = press(sequence);
    return (d.upper, d.lower);
  }

  group('CALC (manual p.38-39)', () {
    test('3A + B with (5, 10) then (7, 20)', () {
      expect(screen('3 A + B'), ('3A+B', '0.'));
      expect(screen('CALC'), ('A?', '0.'));
      expect(screen('5'), ('A', '5.'));
      expect(screen('='), ('B?', '0.'));
      expect(screen('10 ='), ('3A+B', '25.'));
      expect(screen('CALC'), ('A?', '5.'));
      expect(screen('7 = 20 ='), ('3A+B', '41.'));
    });
    test('= on a prompt keeps the current value', () {
      press('2 STO kA AC A × 3 CALC');
      expect(screen('='), ('A×3', '6.'));
    });
    test('= after a result restarts the prompts', () {
      press('A + 1 CALC 4 =');
      expect(screen('='), ('A?', '4.'));
    });
    test('negative and decimal input at a prompt', () {
      press('A × 2 CALC (-) 1.5');
      expect(calc.display.lower, '-1.5');
      expect(screen('='), ('A×2', '-3.'));
    });
    test('DEL edits the value being typed', () {
      press('A CALC 12 DEL 3 =');
      expect(calc.display.lower, '13.');
    });
    test('Y = expression stores the result in Y and does not prompt for Y', () {
      press('Y eq 2 X CALC');
      expect(calc.display.upper, 'X?');
      press('21 =');
      expect(calc.display.lower, '42.');
      expect(screen('AC RCL kY'), ('Y=', '42.'));
    });
    test('expression without variables evaluates directly', () {
      expect(screen('2 + 3 CALC'), ('2+3', '5.'));
    });
    test('AC leaves CALC', () {
      expect(screen('A CALC AC'), ('', '0.'));
    });
    test('= sign outside CALC/SOLVE is a Syntax ERROR', () {
      expect(press('Y eq 2 =').upper, 'Syntax ERROR');
    });
    test('updates Ans', () {
      press('A + 1 CALC 1 =');
      expect(screen('AC Ans ='), ('Ans', '2.'));
    });
  });

  group('SOLVE (manual p.39-40)', () {
    test('Y = AX² + B for X with Y=0, A=1, B=-2', () {
      press('Y eq A X x2 + B');
      expect(screen('SOLVE'), ('Y?', '0.'));
      expect(screen('0 ='), ('A?', '0.'));
      expect(screen('1 ='), ('X?', '0.'));
      expect(screen('down'), ('B?', '0.'));
      press('(-) 2 =');
      expect(screen('up'), ('X?', '0.'));
      press('1 SOLVE');
      expect(screen(''), ('X=', '1.414213562'));
      expect(screen('AC RCL kX'), ('X=', '1.414213562'));
    });
    test('without = it solves expression = 0', () {
      press('X x2 - 9 SOLVE 1 SOLVE');
      expect(calc.display.lower, '3.');
    });
    test('initial value picks the root', () {
      press('X x2 - 9 SOLVE (-) 1 SOLVE');
      expect(calc.display.lower, '-3.');
    });
    test('no solution → Can\'t Solve', () {
      press('X x2 + 1 SOLVE 1 SOLVE');
      expect(calc.display.upper, "Can't Solve");
    });
    test('∫ inside SOLVE is not allowed', () {
      press('∫dx X , 0 , 1 ) - X SOLVE 1 SOLVE');
      expect(calc.display.upper, 'Syntax ERROR');
    });
    test('AC leaves SOLVE', () {
      expect(screen('X SOLVE AC'), ('', '0.'));
    });
    test('solving again from the result', () {
      press('X x2 - 4 SOLVE 1 SOLVE');
      expect(calc.display.lower, '2.');
      expect(screen('SOLVE').$1, 'X?');
    });
  });
}
