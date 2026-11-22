import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void main() {
  late Calculator calc;

  setUp(() => calc = Calculator());

  void press(List<CalcKey> keys) => keys.forEach(calc.press);

  group('initial state', () {
    test('shows empty input and 0. result', () {
      expect(calc.display.upper, '');
      expect(calc.display.lower, '0.');
      expect(calc.display.indicators, isEmpty);
    });
  });

  group('digit input', () {
    test('digits appear on the upper line in order', () {
      press([CalcKey.d1, CalcKey.d2, CalcKey.d3]);
      expect(calc.display.upper, '123');
    });

    test('every digit key maps to its value', () {
      press([
        CalcKey.d0,
        CalcKey.d1,
        CalcKey.d2,
        CalcKey.d3,
        CalcKey.d4,
        CalcKey.d5,
        CalcKey.d6,
        CalcKey.d7,
        CalcKey.d8,
        CalcKey.d9,
      ]);
      expect(calc.display.upper, '0123456789');
    });

    test('non-digit keys have no digit value', () {
      expect(CalcKey.sin.digit, isNull);
    });

    test('AC clears the input line', () {
      press([CalcKey.d4, CalcKey.d5, CalcKey.ac]);
      expect(calc.display.upper, '');
      expect(calc.display.lower, '0.');
    });
  });

  group('SHIFT modifier', () {
    test('SHIFT shows the S indicator', () {
      calc.press(CalcKey.shift);
      expect(calc.display.indicators, contains(Indicator.shift));
    });

    test('SHIFT pressed twice cancels', () {
      press([CalcKey.shift, CalcKey.shift]);
      expect(calc.display.indicators, isNot(contains(Indicator.shift)));
    });

    test('SHIFT is consumed by the next key', () {
      press([CalcKey.shift, CalcKey.d1]);
      expect(calc.display.indicators, isNot(contains(Indicator.shift)));
    });
  });

  group('ALPHA modifier', () {
    test('ALPHA shows the A indicator and replaces SHIFT', () {
      press([CalcKey.shift, CalcKey.alpha]);
      expect(calc.display.indicators, contains(Indicator.alpha));
      expect(calc.display.indicators, isNot(contains(Indicator.shift)));
    });

    test('ALPHA pressed twice cancels', () {
      press([CalcKey.alpha, CalcKey.alpha]);
      expect(calc.display.indicators, isEmpty);
    });
  });

  test('DisplayState has a readable toString for test failures', () {
    expect(calc.display.toString(), contains('0.'));
  });
}
