import 'package:test/test.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/frac.dart';
import 'package:wcalc_engine/src/number/value.dart';

Frac f(int n, [int d = 1]) => Frac(BigInt.from(n), BigInt.from(d));
Value fv(int n, [int d = 1]) => Value.frac(f(n, d));
Value dv(String s) => Value.dec(Dec.parse(s));

void main() {
  group('Frac', () {
    test('normalizes sign and gcd', () {
      expect(f(2, 4).toString(), '1/2');
      expect(f(3, -6).toString(), '-1/2');
      expect(f(0, 5).toString(), '0/1');
    });
    test('arithmetic', () {
      expect((f(2, 3) + f(1, 5)).toString(), '13/15');
      expect((f(1, 2) - f(3, 4)).toString(), '-1/4');
      expect((f(2, 3) * f(3, 4)).toString(), '1/2');
      expect((f(1, 2) / f(1, 4)).toString(), '2/1');
      expect(f(2, 3).pow(3).toString(), '8/27');
      expect(f(2, 3).pow(-2).toString(), '9/4');
    });
    test('division by zero is a Math ERROR', () {
      expect(() => f(1, 2) / f(0), throwsA(isA<CalcError>()));
      expect(() => Frac(BigInt.one, BigInt.zero), throwsA(isA<CalcError>()));
    });
    test('decimal conversion', () {
      expect(f(1, 3).toDec().toString(), '0.333333333333333');
      expect(Frac.fromDec(Dec.parse('2.75')).toString(), '11/4');
    });
    test('best fraction for a decimal (a b/c key)', () {
      expect(Frac.approximate(Dec.parse('2.75')).toString(), '11/4');
      expect(
        Frac.approximate(Dec.parse('0.333333333333333')).toString(),
        '1/3',
      );
      expect(
        Frac.approximate(Dec.parse('0.142857142857143')).toString(),
        '1/7',
      );
      expect(Frac.approximate(Dec.parse('3.14159265358980')), isNull);
    });
    test('mixed parts', () {
      expect(f(11, 4).mixed, (BigInt.two, BigInt.from(3), BigInt.from(4)));
      expect(f(-5, 3).mixed, (BigInt.from(-1), BigInt.two, BigInt.from(3)));
    });
  });

  group('Value mixing rules (manual p.19)', () {
    test('fraction + fraction stays a fraction', () {
      final r = fv(2, 3) + fv(1, 5);
      expect(r.frac.toString(), '13/15');
    });
    test('fraction with an integer stays a fraction', () {
      expect((fv(1, 2) + dv('3')).frac.toString(), '7/2');
      expect((dv('2') * fv(1, 3)).frac.toString(), '2/3');
    });
    test('fraction with a non-integer decimal becomes decimal', () {
      final r = fv(1, 2) + dv('1.6');
      expect(r.frac, isNull);
      expect(r.dec, Dec.parse('2.1'));
    });
    test('decimals stay decimals even when the result is a ratio', () {
      final r = dv('10') / dv('4');
      expect(r.frac, isNull);
      expect(r.dec, Dec.parse('2.5'));
    });
    test('sexagesimal ± sexagesimal stays sexagesimal', () {
      final a = Value.sexagesimal(Dec.parse('2.5'));
      expect((a + a).isSexagesimal, isTrue);
      expect((a + dv('1')).isSexagesimal, isFalse);
    });
    test('sexagesimal × or ÷ decimal stays sexagesimal', () {
      final a = Value.sexagesimal(Dec.parse('2.5'));
      expect((a * dv('3')).isSexagesimal, isTrue);
      expect((a / dv('2')).isSexagesimal, isTrue);
      expect((a * a).isSexagesimal, isFalse);
    });
    test('negation keeps the kind', () {
      expect((-fv(1, 2)).frac.toString(), '-1/2');
      expect((-Value.sexagesimal(Dec.one)).isSexagesimal, isTrue);
    });
    test('integer powers of fractions stay exact', () {
      expect(fv(2, 3).powInt(2)!.frac.toString(), '4/9');
      expect(dv('2').powInt(2), isNull);
    });
  });
}
