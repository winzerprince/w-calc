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

  group('Pol / Rec (manual p.36-37)', () {
    test('Rec(2, 60) = (1, 1.732050808), y in F', () {
      expect(press('Rec( 2 , 60 )').upper, 'Rec(2,60)');
      vector('=', '1.');
      vector('RCL kF', '1.732050808');
      vector('RCL kE', '1.');
    });
    test('Pol(1, √3) in Rad = (2, 1.047197551)', () {
      vector('$rad Pol( 1 , √ 3 ) =', '2.');
      vector('RCL kF', '1.047197551');
    });
    test('θ range is (-180, 180]', () {
      press('Pol( (-) 1 , 0 ) =');
      vector('RCL kF', '180.');
      press('Pol( 0 , (-) 1 ) =');
      vector('RCL kF', '-90.');
    });
    test('Pol(0, 0) has θ = 0', () {
      vector('Pol( 0 , 0 ) =', '0.');
      vector('RCL kF', '0.');
    });
    test('missing ) at the end is allowed', () => vector('Pol( 3 , 4 =', '5.'));
    test('wrong number of arguments → Syntax ERROR', () {
      expect(press('Pol( 3 ) =').upper, 'Syntax ERROR');
    });
    test('comma outside a function → Syntax ERROR', () {
      expect(press('AC 1 , 2 =').upper, 'Syntax ERROR');
    });
    test('Pol inside an expression', () => vector('2 × Pol( 3 , 4 ) =', '10.'));
  });

  group('CONST (manual p.40)', () {
    test('shows the prompt, then the constant symbol', () {
      expect(press('CONST').upper, 'CONST--');
      expect(press('2').upper, 'CONST2-');
      expect(press('8').upper, 'C₀');
    });
    test('speed of light', () => vector('CONST 28 =', '299792458.'));
    test(
      'implied multiplication: 2c₀',
      () => vector('2 CONST 28 =', '599584916.'),
    );
    test('constant times constant', () {
      vector('CONST 24 × CONST 25 =', '8.314462145');
    });
    test('all 40 constants have values', () {
      for (var i = 1; i <= 40; i++) {
        press('AC CONST ${i.toString().padLeft(2, '0')} =');
        expect(calc.display.upper, isNot(contains('ERROR')), reason: '$i');
      }
    });
    test('invalid numbers are ignored; AC cancels', () {
      expect(press('CONST 4 5').upper, 'CONST4-');
      expect(press('AC').upper, '');
    });
  });

  group('CONV (manual p.42)', () {
    test('-31 °C → °F = -23.8', () {
      expect(press('( (-) 31 ) CONV 38').upper, '(-31)°C▶°F');
      vector('=', '-23.8');
    });
    test('°F → °C', () => vector('212 CONV 37 =', '100.'));
    test('in ↔ cm', () {
      vector('1 CONV 01 =', '2.54');
      vector('AC 2.54 CONV 02 =', '1.');
    });
    test('km/h → m/s', () => vector('36 CONV 19 =', '10.'));
    test('m/s → km/h', () => vector('10 CONV 20 =', '36.'));
    test('J → cal', () => vector('4.1855 CONV 39 =', '1.'));
    test('conversion after a result continues from Ans', () {
      press('100 =');
      expect(press('CONV 07').upper, 'Ansmile▶km');
    });
  });
}
