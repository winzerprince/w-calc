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

  const eqn = 'MODE MODE MODE 1';

  test('entering EQN shows Unknowns?, ▶ shows Degree?', () {
    final d = press(eqn);
    expect(d.upper, 'Unknowns?→');
    expect(d.menuMarks, {0: '2', 4: '3'});
    expect(press('>').upper, '←Degree?');
    expect(press('<').upper, 'Unknowns?→');
  });

  group('simultaneous (manual p.62)', () {
    test('3 unknowns: x=2 y=5 z=4', () {
      press('$eqn 3');
      expect(screen(''), ('a1?', '0.'));
      expect(calc.display.indicators, contains(Indicator.scrollDown));
      press('2 = 3 = (-) 1 = 15 =');
      expect(screen(''), ('a2?', '0.'));
      press('3 = (-) 2 = 2 = 4 =');
      press('5 = 3 = (-) 4 =');
      expect(screen('9 ='), ('x=', '2.'));
      expect(screen('down'), ('y=', '5.'));
      expect(screen('down'), ('z=', '4.'));
      expect(screen('down'), ('z=', '4.'));
      expect(screen('up up'), ('x=', '2.'));
    });
    test('typing shows the name without ?', () {
      press('$eqn 2');
      expect(screen('12'), ('a1', '12.'));
    });
    test('▲ ▼ move between coefficients before the last one', () {
      press('$eqn 2 1 = 2 =');
      expect(screen('up'), ('b1?', '2.'));
      expect(screen('up'), ('a1?', '1.'));
    });
    test('AC returns to coefficient input with values kept', () {
      press('$eqn 2 1 = 1 = 3 = 1 = (-) 1 = 1 =');
      expect(screen(''), ('x=', '2.'));
      expect(screen('AC'), ('a1?', '1.'));
      expect(screen('= = = = = ='), ('x=', '2.'));
    });
    test('no unique solution → Math ERROR', () {
      expect(press('$eqn 2 1 = 2 = 3 = 2 = 4 = 6 =').upper, 'Math ERROR');
    });
  });

  group('quadratic / cubic (manual p.60-61)', () {
    test('x³ - 2x² - x + 2 = 0', () {
      press('$eqn > 3');
      expect(screen(''), ('a?', '0.'));
      expect(screen('1 = (-) 2 = (-) 1 = 2 ='), ('x1=', '2.'));
      expect(screen('down'), ('x2=', '-1.'));
      expect(screen('down'), ('x3=', '1.'));
    });
    test('8x² - 4x + 5 = 0: complex roots with Re⇔Im', () {
      press('$eqn > 2 8 = (-) 4 = 5 =');
      expect(screen(''), ('x1=', '0.25'));
      expect(calc.display.indicators, contains(Indicator.reIm));
      expect(screen('ReIm'), ('x1=', '0.75'));
      expect(calc.display.indicators, contains(Indicator.imaginary));
      expect(screen('down'), ('x2=', '0.25'));
      expect(screen('ReIm'), ('x2=', '-0.75'));
    });
    test('a = 0 → Math ERROR', () {
      expect(press('$eqn > 2 0 = 1 = 1 =').upper, 'Math ERROR');
    });
    test('EQN indicator-free arithmetic is not available while solving', () {
      press('$eqn > 2 1 = (-) 3 = 2 =');
      expect(screen('5'), ('x1=', '2.'));
    });
  });

  test('coefficients survive a snapshot', () {
    press('$eqn 2 4 = 5 =');
    final c = Calculator()..restoreState(calc.saveState());
    keys('').forEach(c.press);
    expect(c.mode, CalcMode.eqn);
  });
}
