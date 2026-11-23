import 'package:test/test.dart';
import 'package:wcalc_engine/src/eqn/solvers.dart';
import 'package:wcalc_engine/src/format/number_format.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/value.dart';

Dec d(String s) => Dec.parse(s);
List<Dec> ds(List<String> s) => s.map(d).toList();

/// As displayed (Norm 1), re[+im i].
String show(Value v) {
  String f(Dec x) {
    final r = formatNumber(x, const DisplayFormat.norm1());
    final m = r.mantissa.endsWith('.')
        ? r.mantissa.substring(0, r.mantissa.length - 1)
        : r.mantissa;
    return r.exponent == null ? m : '${m}e${r.exponent}';
  }

  return v.isComplex
      ? '${f(v.dec)}${v.imag.isNegative ? '' : '+'}${f(v.imag)}i'
      : f(v.dec);
}

void main() {
  group('simultaneous equations', () {
    test('3 unknowns (manual p.62): x=2 y=5 z=4', () {
      final r = solveLinear([
        ds(['2', '3', '-1', '15']),
        ds(['3', '-2', '2', '4']),
        ds(['5', '3', '-4', '9']),
      ]);
      expect(r.map(show), ['2', '5', '4']);
    });
    test('2 unknowns', () {
      final r = solveLinear([
        ds(['1', '1', '3']),
        ds(['1', '-1', '1']),
      ]);
      expect(r.map(show), ['2', '1']);
    });
    test('no unique solution → Math ERROR', () {
      expect(
        () => solveLinear([
          ds(['1', '2', '3']),
          ds(['2', '4', '6']),
        ]),
        throwsA(isA<CalcError>()),
      );
    });
  });

  group('quadratic', () {
    test('8x² - 4x + 5 = 0 → 0.25 ± 0.75i (manual p.61)', () {
      final r = solvePolynomial(ds(['8', '-4', '5']));
      expect(r.map(show), ['0.25+0.75i', '0.25-0.75i']);
    });
    test('real roots: larger first for a > 0', () {
      expect(solvePolynomial(ds(['1', '-3', '2'])).map(show), ['2', '1']);
    });
    test(
      'double root',
      () => expect(solvePolynomial(ds(['1', '-2', '1'])).map(show), ['1', '1']),
    );
    test('large b stays accurate (no cancellation)', () {
      final r = solvePolynomial(ds(['1', '1e8', '1']));
      expect(show(r[0]), '-1e-08');
    });
    test('a = 0 → Math ERROR', () {
      expect(
        () => solvePolynomial(ds(['0', '1', '1'])),
        throwsA(isA<CalcError>()),
      );
    });
  });

  group('cubic', () {
    test('x³ - 2x² - x + 2 = 0 → 2, -1, 1 (manual p.60, device order)', () {
      expect(solvePolynomial(ds(['1', '-2', '-1', '2'])).map(show), [
        '2',
        '-1',
        '1',
      ]);
    });
    test('one real root and a complex pair', () {
      // x³ - 1 = 0 → 1, -0.5 ± 0.866…i
      expect(solvePolynomial(ds(['1', '0', '0', '-1'])).map(show), [
        '1',
        '-0.5+0.866025404i',
        '-0.5-0.866025404i',
      ]);
    });
    test(
      'triple root',
      () => expect(solvePolynomial(ds(['1', '-3', '3', '-1'])).map(show), [
        '1',
        '1',
        '1',
      ]),
    );
    test('a = 0 → Math ERROR', () {
      expect(
        () => solvePolynomial(ds(['0', '1', '1', '1'])),
        throwsA(isA<CalcError>()),
      );
    });
  });
}
