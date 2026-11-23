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
    return (d.upper, d.exponent == null ? d.lower : '${d.lower}e${d.exponent}');
  }

  const sd = 'MODE MODE 1';
  const data = '55 DT 54 DT 51 DT 55 DT 53 DT DT 54 DT 52 DT';

  group('SD mode (manual p.46-49)', () {
    setUp(() => press('$sd CLR 1 ='));

    test('SD indicator; Scl in the CLR menu', () {
      expect(calc.display.indicators, contains(Indicator.sd));
      expect(press('CLR').upper, 'Scl Mode All');
      press('AC');
    });
    test('DT shows n=', () {
      expect(screen('55 DT'), ('n=', '1.'));
      expect(screen('54 DT'), ('n=', '2.'));
    });
    test('DT DT enters the same value twice', () {
      press('53 DT DT');
      expect(screen('S-SUM 3 ='), ('n', '2.'));
    });
    test('manual example results', () {
      press(data);
      expect(screen('S-VAR 3 =').$2, '1.407885953');
      expect(screen('S-VAR 2 =').$2, '1.316956719');
      expect(screen('S-VAR 1 =').$2, '53.375');
      expect(screen('S-SUM 3 =').$2, '8.');
      expect(screen('S-SUM 2 =').$2, '427.');
      expect(screen('S-SUM 1 =').$2, '22805.');
    });
    test('menus', () {
      expect(press('S-SUM').upper, 'Σx² Σx n');
      expect(press('AC S-VAR').upper, ' xσn xσn-1');
      expect(press('AC DISTR').upper, 'P( Q( R( →t');
      press('AC');
    });
    test('frequency with ;', () {
      press('110 ; 10 DT');
      expect(screen('S-SUM 3 =').$2, '10.');
      expect(screen('S-SUM 2 =').$2, '1100.');
    });
    test('stat values work in expressions', () {
      press(data);
      expect(screen('S-SUM 2 ÷ S-SUM 3 =').$2, '53.375');
    });
    test('normal distribution (manual p.55)', () {
      press(data);
      expect(screen('53 DISTR 4 =').$2, '-0.284747399');
      expect(screen('DISTR 1 (-) 0.28 ) =').$2, '0.38974');
      expect(screen('DISTR 3 1.5 ) =').$2, '0.06681');
    });
    test('no data → Math ERROR', () {
      expect(press('S-VAR 1 =').upper, 'Math ERROR');
    });
    test('CL removes the value just entered', () {
      press('5 DT 7 DT CL');
      expect(screen('S-SUM 2 =').$2, '5.');
    });
    test('Scl clears the data', () {
      press('5 DT CLR 1 =');
      expect(screen('S-SUM 3 =').$2, '0.');
    });
  });

  group('data editing with ▲ ▼ (manual p.49)', () {
    setUp(() => press('$sd CLR 1 = 10 DT 20 DT 30 ; 2 DT'));

    test('scrolls through items and frequencies', () {
      expect(screen('up'), ('x3=', '30.'));
      expect(screen('down'), ('Freq3=', '2.'));
      expect(screen('up up'), ('x2=', '20.'));
      expect(screen('up up'), ('x1=', '10.'));
    });
    test('typing + = replaces the value', () {
      press('up up up 15 =');
      press('AC');
      expect(screen('S-SUM 2 =').$2, '95.');
    });
    test('typing + DT adds a new item and keeps the old', () {
      press('up up up 15 DT');
      press('AC');
      expect(screen('S-SUM 3 =').$2, '5.');
    });
    test('CL deletes the shown item', () {
      press('up up up CL');
      press('AC');
      expect(screen('S-SUM 2 =').$2, '80.');
    });
  });

  group('REG mode (manual p.50-54)', () {
    const lin = 'MODE MODE 2 1';
    test('type menu pages', () {
      expect(press('MODE MODE 2').upper, 'Lin Log Exp→');
      expect(press('>').upper, '←Pwr Inv Quad');
      press('<');
      expect(press('1').indicators, contains(Indicator.reg));
    });
    test('linear example', () {
      press('$lin CLR 1 =');
      press('10 , 1003 DT 15 , 1005 DT 20 , 1010 DT 25 , 1011 DT 30 , 1014 DT');
      expect(screen('S-VAR > > 1 =').$2, '997.4');
      expect(screen('S-VAR > > 2 =').$2, '0.56');
      expect(screen('S-VAR > > 3 =').$2, '0.982607369');
      expect(screen('( (-) 5 ) S-VAR > > > 2 =').$2, '994.6');
      expect(screen('1000 S-VAR > > > 1 =').$2, '4.642857143');
      expect(screen('S-VAR > > 3 x2 =').$2, '0.965517241');
      expect(
        screen(
          '( S-SUM > 3 - S-SUM 3 × S-VAR 1 × S-VAR > 1 ) ÷ ( S-SUM 3 - 1 ) =',
        ).$2,
        '35.',
      );
    });
    test('quadratic example', () {
      press('MODE MODE 2 > 3 CLR 1 =');
      press(
        '29 , 1.6 DT 50 , 23.5 DT 74 , 38.0 DT 103 , 46.4 DT 118 , 48.0 DT',
      );
      expect(screen('S-VAR > > 1 =').$2, '-35.59856934');
      expect(screen('S-VAR > > 2 =').$2, '1.495939413');
      expect(screen('S-VAR > > 3 =').$2, '-6.71629667e-03');
      expect(screen('16 S-VAR > > > 3 =').$2, '-13.38291067');
      expect(screen('20 S-VAR > > > 1 =').$2, '47.14556728');
      expect(screen('20 S-VAR > > > 2 =').$2, '175.5872105');
      expect(press('S-SUM > >').upper, '←Σx³ Σx²y Σx⁴');
      press('AC');
    });
    test('REG data screens show x and y', () {
      press('$lin CLR 1 = 1 , 2 DT up');
      expect(screen(''), ('x1=', '1.'));
      expect(screen('down'), ('y1=', '2.'));
    });
    test('choosing a regression type clears A-F, X, Y', () {
      press('7 STO kA MODE MODE 2 1');
      expect(screen('AC RCL kA'), ('A=', '0.'));
    });
    test('DISTR is SD only', () {
      expect(press('$lin DISTR').upper, '');
    });
  });

  test('stat data survives a snapshot', () {
    press('$sd CLR 1 = 4 DT 6 DT');
    final c = Calculator()..restoreState(calc.saveState());
    keys('S-VAR 1 =').forEach(c.press);
    expect(c.display.lower, '5.');
  });

  test('M+ is DT in SD, so independent memory is untouched', () {
    press('$sd CLR 1 = 9 DT');
    expect(calc.display.indicators, isNot(contains(Indicator.memory)));
  });
}
