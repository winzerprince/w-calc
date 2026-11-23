import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/src/eval/evaluator.dart';
import 'package:wcalc_engine/src/input/token.dart';
import 'package:wcalc_engine/src/number/dec.dart';

List<Tok> n(int v) => [
  for (final c in '$v'.split('')) Tok.digits[int.parse(c)],
];

String ev(List<Tok> t) => evaluateValue(t, EvalContext()).toString();

CalcErrorKind? err(List<Tok> t) {
  try {
    evaluateValue(t, EvalContext());
    return null;
  } on CalcError catch (e) {
    return e.kind;
  }
}

List<Tok> frac(int a, int b) => [
  Tok.openParen,
  ...n(a),
  Tok.closeParen,
  Tok.fracDiv,
  Tok.openParen,
  ...n(b),
  Tok.closeParen,
];

void main() {
  test('fraction bar is exact: 2/3 + 1/2 = 7/6', () {
    expect(ev([...frac(2, 3), Tok.add, ...frac(1, 2)]), contains('7/6'));
  });
  test('fraction binds tighter than (−): −1/2 × 4 = −2', () {
    expect(
      evaluateValue([
        Tok.negative,
        ...frac(1, 2),
        Tok.multiply,
        Tok.d4,
      ], EvalContext()).dec,
      Dec.fromInt(-2),
    );
  });
  test('fraction over zero is a Math ERROR', () {
    expect(err(frac(1, 0)), CalcErrorKind.math);
  });
  test('Σ(X+1, 1, 5) = 20', () {
    final v = evaluateValue([
      Tok.sigma,
      Tok.varX,
      Tok.add,
      Tok.d1,
      Tok.comma,
      Tok.d1,
      Tok.comma,
      Tok.d5,
      Tok.closeParen,
    ], EvalContext());
    expect(v.dec, Dec.fromInt(20));
  });
  test('Σ with b < a is a Math ERROR', () {
    expect(
      err([
        Tok.sigma,
        Tok.varX,
        Tok.comma,
        Tok.d5,
        Tok.comma,
        Tok.d1,
        Tok.closeParen,
      ]),
      CalcErrorKind.math,
    );
  });
  test('log(2, 16) = 4 and log(1000) = 3', () {
    expect(
      evaluateValue([
        Tok.logBase,
        Tok.d2,
        Tok.comma,
        ...n(16),
        Tok.closeParen,
      ], EvalContext()).dec,
      Dec.fromInt(4),
    );
    expect(
      evaluateValue([
        Tok.logBase,
        ...n(1000),
        Tok.closeParen,
      ], EvalContext()).dec,
      Dec.fromInt(3),
    );
  });
  test('RanInt#(1, 6) stays in range', () {
    final ctx = EvalContext(random: math.Random(7));
    for (var i = 0; i < 50; i++) {
      final v = evaluateValue([
        Tok.ranInt,
        Tok.d1,
        Tok.comma,
        Tok.d6,
        Tok.closeParen,
      ], ctx).dec;
      expect(v >= Dec.one && v <= Dec.fromInt(6), isTrue);
      expect(v.isInteger, isTrue);
    }
  });
}
