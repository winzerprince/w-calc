import 'package:test/test.dart';
import 'package:wcalc_engine/src/angle_unit.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/functions.dart';

import 'function_vectors.dart';

Dec d(String s) => Dec.parse(s);

Dec apply(String f, AngleUnit? u, List<Dec> a) => switch (f) {
  'sin' => sinDec(a[0], u!),
  'cos' => cosDec(a[0], u!),
  'tan' => tanDec(a[0], u!),
  'asin' => asinDec(a[0], u!),
  'acos' => acosDec(a[0], u!),
  'atan' => atanDec(a[0], u!),
  'sinh' => sinhDec(a[0]),
  'cosh' => coshDec(a[0]),
  'tanh' => tanhDec(a[0]),
  'asinh' => asinhDec(a[0]),
  'acosh' => acoshDec(a[0]),
  'atanh' => atanhDec(a[0]),
  'ln' => lnDec(a[0]),
  'log' => logDec(a[0]),
  'exp' => expDec(a[0]),
  'tenPow' => tenPowDec(a[0]),
  'sqrt' => sqrtDec(a[0]),
  'cbrt' => cbrtDec(a[0]),
  'pow' => powDec(a[0], a[1]),
  'xroot' => xRootDec(a[0], a[1]),
  'fact' => factorialDec(a[0]),
  'nPr' => permutationDec(a[0], a[1]),
  'nCr' => combinationDec(a[0], a[1]),
  _ => throw ArgumentError(f),
};

void main() {
  group('reference vectors (mpmath, 15 digits)', () {
    for (final (f, unit, args, expected) in functionVectors) {
      final u = unit == null ? null : AngleUnit.values.byName(unit);
      test(
        '$f${unit == null ? '' : '[$unit]'}(${args.join(', ')}) = $expected',
        () {
          final input = args.map(d).toList();
          if (expected == 'ERR') {
            expect(() => apply(f, u, input), throwsA(isA<CalcError>()));
          } else {
            expect(apply(f, u, input).toString(), expected);
          }
        },
      );
    }
  });

  group('manual examples', () {
    test(
      'sin 30° = 0.5',
      () => expect(sinDec(d('30'), AngleUnit.deg), d('0.5')),
    );
    test('cos(π/3) = 0.5 in Rad with the device π', () {
      expect(
        cosDec(piConstant / d('3'), AngleUnit.rad).roundSignificant(10),
        d('0.5'),
      );
    });
    test(
      'sin⁻¹ 0.5 = 30°',
      () => expect(asinDec(d('0.5'), AngleUnit.deg), d('30')),
    );
    test('4.25 rad → 243.5070629°', () {
      expect(
        convertAngle(
          d('4.25'),
          AngleUnit.rad,
          AngleUnit.deg,
        ).roundSignificant(10),
        d('243.5070629'),
      );
    });
    test('ln e = 1 with the device e', () {
      expect(lnDec(eConstant).roundSignificant(10), Dec.one);
    });
  });

  group('device-like exactness', () {
    test('sin π = 0 in Rad (snaps to multiples of π/2)', () {
      expect(sinDec(piConstant, AngleUnit.rad).isZero, isTrue);
    });
    test('tan(π/2) in Rad is a Math ERROR', () {
      expect(
        () => tanDec(piConstant / d('2'), AngleUnit.rad),
        throwsA(isA<CalcError>()),
      );
    });
    test('tiny Rad arguments are not snapped', () {
      expect(sinDec(d('1e-13'), AngleUnit.rad), d('1e-13'));
    });
    test(
      'log of a power of ten is exact',
      () => expect(logDec(d('1e-50')), d('-50')),
    );
    test('10^integer is exact', () => expect(tenPowDec(d('-3')), d('0.001')));
  });

  group('domain errors', () {
    void err(Dec Function() f) => expect(f, throwsA(isA<CalcError>()));

    test('trig input limits', () {
      err(() => sinDec(d('9e9'), AngleUnit.deg));
      err(() => cosDec(d('157079632.7'), AngleUnit.rad));
      err(() => tanDec(d('1e10'), AngleUnit.gra));
    });
    test(
      'inverse trig outside [-1, 1]',
      () => err(() => asinDec(d('1.1'), AngleUnit.deg)),
    );
    test('log/ln of 0 or negative', () {
      err(() => lnDec(Dec.zero));
      err(() => logDec(d('-1')));
    });
    test('sqrt of negative', () => err(() => sqrtDec(d('-4'))));
    test('x! needs an integer 0..69', () {
      err(() => factorialDec(d('70')));
      err(() => factorialDec(d('2.5')));
      err(() => factorialDec(d('-1')));
    });
    test('nPr / nCr ranges', () {
      err(() => permutationDec(d('3'), d('4')));
      err(() => combinationDec(d('1e10'), d('1')));
      err(() => combinationDec(d('2.5'), d('1')));
    });
    test('negative base needs integer exponent or 1/odd', () {
      err(() => powDec(d('-8'), d('0.5')));
      expect(powDec(d('-8'), Dec.one / d('3')).roundSignificant(10), d('-2'));
    });
    test('0^0 and 0^negative', () {
      err(() => powDec(Dec.zero, Dec.zero));
      err(() => powDec(Dec.zero, d('-1')));
      expect(powDec(Dec.zero, d('2')), Dec.zero);
    });
    test('x-root rules', () {
      err(() => xRootDec(d('2'), d('-4')));
      expect(xRootDec(d('3'), d('-27')), d('-3'));
      err(() => xRootDec(Dec.zero, d('5')));
      expect(xRootDec(d('2'), Dec.zero), Dec.zero);
    });
    test('overflow', () {
      err(() => expDec(d('231')));
      err(() => tenPowDec(d('100')));
      err(() => powDec(d('10'), d('100')));
      err(() => sinhDec(d('231')));
      err(() => acoshDec(d('0.5')));
      err(() => atanhDec(d('1')));
    });
    test('underflow returns zero', () {
      expect(expDec(d('-300')), Dec.zero);
      expect(tenPowDec(d('-150')), Dec.zero);
      expect(tenPowDec(d('-100.5')), Dec.zero);
    });
  });

  test('simple powers', () {
    expect(squareDec(d('30')), d('900'));
    expect(cubeDec(d('12')), d('1728'));
    expect(reciprocalDec(d('4')), d('0.25'));
  });
}
