import 'package:test/test.dart';
import 'package:wcalc_engine/src/number/dec.dart';

Dec d(String s) => Dec.parse(s);

void main() {
  group('parse / toString', () {
    test('integers, decimals, negatives, exponents', () {
      expect(d('0').toString(), '0');
      expect(d('123').toString(), '123');
      expect(d('-25.5').toString(), '-25.5');
      expect(d('0.0012').toString(), '0.0012');
      expect(d('1.5e3').toString(), '1500');
      expect(d('2e-4').toString(), '0.0002');
      expect(d('000120.500').toString(), '120.5');
    });

    test('rejects garbage', () {
      expect(() => d(''), throwsFormatException);
      expect(() => d('1.2.3'), throwsFormatException);
      expect(() => d('abc'), throwsFormatException);
    });

    test('keeps at most 15 significant digits, rounding half up', () {
      expect(d('1.23456789012345678').toString(), '1.23456789012346');
      expect(d('9.999999999999999').toString(), '10');
      expect(d('-0.1234567890123455').toString(), '-0.123456789012346');
    });
  });

  group('arithmetic is decimal, not binary', () {
    test('0.1 + 0.2 == 0.3 exactly', () {
      expect(d('0.1') + d('0.2'), d('0.3'));
    });

    test('add / subtract with different magnitudes', () {
      expect((d('23') + d('4.5') - d('53')).toString(), '-25.5');
      expect((d('1e20') + d('1')).toString(), '100000000000000000000');
      expect((d('5') - d('5')).isZero, isTrue);
    });

    test('multiply', () {
      expect((d('56') * d('-12')).toString(), '-672');
      expect((d('1.5') * d('1.5')).toString(), '2.25');
    });

    test('divide rounds to 15 significant digits', () {
      expect((d('1') / d('3')).toString(), '0.333333333333333');
      expect((d('2') / d('3')).toString(), '0.666666666666667');
      expect((d('-268.8') / d('-2.5')).toString(), '107.52');
    });

    test('1 / 3 * 3 keeps internal error (display rounding hides it)', () {
      expect((d('1') / d('3') * d('3')).toString(), '0.999999999999999');
    });

    test('division by zero throws math error', () {
      expect(
        () => d('1') / Dec.zero,
        throwsA(
          isA<CalcError>().having((e) => e.kind, 'kind', CalcErrorKind.math),
        ),
      );
    });

    test('negation and abs', () {
      expect((-d('3')).toString(), '-3');
      expect(d('-3').abs(), d('3'));
      expect((-Dec.zero).isZero, isTrue);
    });
  });

  group('comparison', () {
    test('ordering', () {
      expect(d('1') < d('2'), isTrue);
      expect(d('-1') < d('-0.5'), isTrue);
      expect(d('0.1') > d('0.01'), isTrue);
      expect(d('2') >= d('2'), isTrue);
      expect(d('2') <= d('1'), isFalse);
      expect(d('1.0').compareTo(d('1')), 0);
    });

    test('equal values have equal hash codes', () {
      expect(d('1.50').hashCode, d('1.5').hashCode);
    });
  });

  group('range (±1e-99 .. ±9.999999999e99)', () {
    test('results of magnitude >= 1e100 throw math error', () {
      expect(() => d('1e99') * d('10'), throwsA(isA<CalcError>()));
    });

    test('results below 1e-99 underflow to zero', () {
      expect((d('1e-99') / d('10')).isZero, isTrue);
    });

    test('largest value is accepted', () {
      expect(d('9.999999999e99').toString(), startsWith('9999999999'));
    });
  });

  group('helpers', () {
    test('exponent10 gives floor(log10|x|)', () {
      expect(d('123').exponent10, 2);
      expect(d('0.05').exponent10, -2);
      expect(d('1').exponent10, 0);
    });

    test('roundSignificant', () {
      expect(
        d('2.718281828459045').roundSignificant(10).toString(),
        '2.718281828',
      );
      expect(d('9999999999.6').roundSignificant(10).toString(), '10000000000');
    });

    test('roundDecimals', () {
      expect(d('14.2857142857143').roundDecimals(3).toString(), '14.286');
      expect(d('-0.5').roundDecimals(0).toString(), '-1');
      expect(d('0.0004').roundDecimals(3).isZero, isTrue);
    });

    test('integer checks', () {
      expect(d('40320').isInteger, isTrue);
      expect(d('0.5').isInteger, isFalse);
      expect(d('-12').toInt(), -12);
    });

    test('fromInt', () {
      expect(Dec.fromInt(-42).toString(), '-42');
      expect(Dec.one + Dec.one, Dec.fromInt(2));
    });
  });
}
