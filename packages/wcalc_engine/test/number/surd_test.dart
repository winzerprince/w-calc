import 'package:test/test.dart';
import 'package:wcalc_engine/src/number/frac.dart';
import 'package:wcalc_engine/src/number/surd.dart';

Frac f(int n, [int d = 1]) => Frac(BigInt.from(n), BigInt.from(d));
Surd s(int b, int n, [int d = 1]) => Surd.of({BigInt.from(b): f(n, d)})!;

void main() {
  test('√8 = 2√2, √(1/2) = √2/2, √9 = 3', () {
    expect(Surd.sqrtOf(f(8)), s(2, 2));
    expect(Surd.sqrtOf(f(1, 2)), s(2, 1, 2));
    expect(Surd.sqrtOf(f(9))!.isRational, isTrue);
    expect(Surd.sqrtOf(f(9))!.rationalPart, f(3));
  });
  test('√2 × √3 = √6, √2 × √2 = 2', () {
    expect(s(2, 1) * s(3, 1), s(6, 1));
    final two = (s(2, 1) * s(2, 1))!;
    expect(two.isRational, isTrue);
    expect(two.rationalPart, f(2));
  });
  test('(√2 + 2) × √3 = 2√3 + √6', () {
    final r = ((s(2, 1) + Surd.rational(f(2)))! * s(3, 1))!;
    expect(r.radicals, [(BigInt.from(3), f(2)), (BigInt.from(6), f(1))]);
    expect(r.toDec().toString(), '5.91359135792093');
  });
  test('1 ÷ √2 = √2/2', () {
    expect(Surd.rational(f(1)) / s(2, 1), s(2, 1, 2));
  });
  test('too many terms gives up', () {
    final a = (s(2, 1) + s(3, 1))!;
    final b = (s(5, 1) + s(7, 1))!;
    expect(a * b, isNull); // four radicals
  });
  test('decimal value of (1 + √5)/2', () {
    final phi = (Surd.rational(f(1, 2)) + s(5, 1, 2))!;
    expect(phi.toDec().toString(), '1.61803398874989');
  });
}
