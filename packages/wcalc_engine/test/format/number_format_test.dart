import 'package:test/test.dart';
import 'package:wcalc_engine/src/format/number_format.dart';
import 'package:wcalc_engine/src/number/dec.dart';

Dec d(String s) => Dec.parse(s);

void main() {
  const norm1 = DisplayFormat.norm1();
  const norm2 = DisplayFormat.norm2();

  void expectShown(Dec v, DisplayFormat f, String mantissa, [String? exp]) {
    final r = formatNumber(v, f);
    expect(
      (r.mantissa, r.exponent),
      (mantissa, exp),
      reason: 'value $v with $f',
    );
  }

  group('Norm 1 (default)', () {
    test('integers get a trailing point', () {
      expectShown(d('36'), norm1, '36.');
      expectShown(Dec.zero, norm1, '0.');
      expectShown(d('-40320'), norm1, '-40320.');
      expectShown(d('9999999999'), norm1, '9999999999.');
    });

    test('decimals show up to 10 digits in total, trailing zeros trimmed', () {
      expectShown(d('-25.5'), norm1, '-25.5');
      expectShown(d('0.3'), norm1, '0.3');
      expectShown(d('3.14159265358980'), norm1, '3.141592654');
      expectShown(d('2.71828182845904'), norm1, '2.718281828');
      expectShown(d('2') / d('3'), norm1, '0.666666667');
      expectShown(d('1') / d('81'), norm1, '0.012345679');
      expectShown(d('0.0899051114393979'), norm1, '0.089905111');
      expectShown(d('-0.612800788139932'), norm1, '-0.612800788');
    });

    test('1 / 3 * 3 shows 1', () {
      expectShown(d('1') / d('3') * d('3'), norm1, '1.');
    });

    test('|x| >= 1e10 switches to exponential with 10 significant digits', () {
      expectShown(d('2') / d('3') * d('1e20'), norm1, '6.666666667', '19');
      expectShown(d('1e10'), norm1, '1.', '10');
      expectShown(d('-1.23e45'), norm1, '-1.23', '45');
    });

    test('rounding up to 1e10 also switches to exponential', () {
      expectShown(d('9999999999.6'), norm1, '1.', '10');
    });

    test('|x| < 0.01 switches to exponential', () {
      expectShown(d('1') / d('200'), norm1, '5.', '-03');
      expectShown(d('0.01'), norm1, '0.01');
      expectShown(d('-1e-99'), norm1, '-1.', '-99');
    });
  });

  group('Norm 2', () {
    test('small values stay fixed down to 1e-9', () {
      expectShown(d('1') / d('200'), norm2, '0.005');
      expectShown(d('0.000000001'), norm2, '0.000000001');
      expectShown(d('1.5e-10'), norm2, '1.5', '-10');
    });
  });

  group('Fix', () {
    test('always shows exactly n decimals', () {
      expectShown(d('100') / d('7'), const DisplayFormat.fix(3), '14.286');
      expectShown(d('100') / d('7'), const DisplayFormat.fix(2), '14.29');
      expectShown(d('10'), const DisplayFormat.fix(3), '10.000');
      expectShown(d('0.0004'), const DisplayFormat.fix(3), '0.000');
      expectShown(d('2.5'), const DisplayFormat.fix(0), '3.');
    });
  });

  group('Sci', () {
    test('mantissa with exactly n significant digits', () {
      expectShown(d('1') / d('7'), const DisplayFormat.sci(5), '1.4286', '-01');
      expectShown(d('1') / d('3'), const DisplayFormat.sci(2), '3.3', '-01');
      expectShown(d('1500'), const DisplayFormat.sci(3), '1.50', '03');
    });

    test('Sci 0 means 10 digits', () {
      expectShown(
        d('1') / d('7'),
        const DisplayFormat.sci(0),
        '1.428571429',
        '-01',
      );
    });

    test('rounding can carry into the exponent', () {
      expectShown(d('9.99'), const DisplayFormat.sci(2), '1.0', '01');
    });

    test('zero', () {
      expectShown(Dec.zero, const DisplayFormat.sci(3), '0.00', '00');
    });
  });

  test('DisplayFormat describes itself', () {
    expect(const DisplayFormat.fix(3).toString(), 'Fix 3');
    expect(norm1.toString(), 'Norm 1');
  });
}
