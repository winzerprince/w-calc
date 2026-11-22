import 'package:test/test.dart';
import 'package:wcalc_engine/src/eval/evaluator.dart';
import 'package:wcalc_engine/src/input/token.dart';
import 'package:wcalc_engine/src/number/dec.dart';

/// Builds tokens from a compact string: digits, `.`, `E`, `+ - × ÷ ( )`,
/// `~` for the (−) negative sign, `@` for Ans.
List<Tok> t(String s) => [
  for (final c in s.replaceAll(' ', '').split(''))
    switch (c) {
      '+' => Tok.add,
      '-' => Tok.subtract,
      '×' => Tok.multiply,
      '÷' => Tok.divide,
      '(' => Tok.openParen,
      ')' => Tok.closeParen,
      '~' => Tok.negative,
      '.' => Tok.point,
      'E' => Tok.exp,
      '@' => Tok.ans,
      _ => Tok.digits[int.parse(c)],
    },
];

String ev(String s, {Dec? ans}) =>
    evaluate(t(s), ans: ans ?? Dec.zero).toString();

CalcErrorKind? err(String s) {
  try {
    evaluate(t(s), ans: Dec.zero);
    return null;
  } on CalcError catch (e) {
    return e.kind;
  }
}

void main() {
  group('manual arithmetic examples', () {
    test('23 + 4.5 - 53 = -25.5', () => expect(ev('23+4.5-53'), '-25.5'));
    test(
      '56 × (-12) ÷ (-2.5) = 268.8',
      () => expect(ev('56×(~12)÷(~2.5)'), '268.8'),
    );
    test(
      '2 ÷ 3 × (1 × 10^20)',
      () => expect(ev('2÷3×1E20'), '66666666666666700000'),
    );
    test('7 × 8 - 4 × 5 = 36', () => expect(ev('7×8-4×5'), '36'));
    test('6 ÷ (4 × 5) = 0.3', () => expect(ev('6÷(4×5)'), '0.3'));
    test(
      '2 × (7 + 6 × (5 + 4)) = 122',
      () => expect(ev('2×(7+6×(5+4))'), '122'),
    );
    test(
      'missing final ) is allowed: (2+3)×(4-1 = 15',
      () => expect(ev('(2+3)×(4-1'), '15'),
    );
  });

  group('literals', () {
    test(
      'EXP with negative exponent: 2.34E(-)5',
      () => expect(ev('2.34E~5'), '0.0000234'),
    );
    test('leading point', () => expect(ev('.5+1'), '1.5'));
    test('EXP without mantissa means 1E', () => expect(ev('E3'), '1000'));
    test(
      'two points is a syntax error',
      () => expect(err('1.2.3'), CalcErrorKind.syntax),
    );
    test(
      'EXP with too many exponent digits',
      () => expect(err('1E123'), CalcErrorKind.syntax),
    );
  });

  group('negative sign (Type B, binds looser than powers)', () {
    test('leading negative', () => expect(ev('~3+5'), '2'));
    test('negative after operator', () => expect(ev('2×~3'), '-6'));
    test('double negative', () => expect(ev('~~4'), '4'));
    test('negative of parenthesis', () => expect(ev('~(2+3)'), '-5'));
  });

  group('Ans', () {
    test(
      'Ans in expression',
      () => expect(ev('789-@', ans: Dec.fromInt(579)), '210'),
    );
  });

  group('implied multiplication', () {
    test('number before parenthesis', () => expect(ev('2(3+4)'), '14'));
    test(
      'parenthesis before parenthesis',
      () => expect(ev('(1+1)(2+3)'), '10'),
    );
    test(
      'number before Ans',
      () => expect(ev('3@', ans: Dec.fromInt(5)), '15'),
    );
    test(
      'binds tighter than ÷: 6 ÷ 2(1+2) = 1',
      () => expect(ev('6÷2(1+2)'), '1'),
    );
  });

  group('errors', () {
    test(
      'division by zero → Math ERROR',
      () => expect(err('1÷0'), CalcErrorKind.math),
    );
    test(
      'overflow → Math ERROR',
      () => expect(err('1E99×10'), CalcErrorKind.math),
    );
    test(
      'dangling operator → Syntax ERROR',
      () => expect(err('2+'), CalcErrorKind.syntax),
    );
    test(
      'leading binary operator → Syntax ERROR',
      () => expect(err('×2'), CalcErrorKind.syntax),
    );
    test(
      'unmatched ) → Syntax ERROR',
      () => expect(err('2)'), CalcErrorKind.syntax),
    );
    test(
      'empty parentheses → Syntax ERROR',
      () => expect(err('()'), CalcErrorKind.syntax),
    );
    test(
      'number after ) → Syntax ERROR',
      () => expect(err('(2)3'), CalcErrorKind.syntax),
    );
    test(
      'empty expression → Syntax ERROR',
      () => expect(err(''), CalcErrorKind.syntax),
    );
  });

  group('stacks (numeric 10, command 24)', () {
    test('deep but legal nesting works', () {
      expect(ev('${'(' * 20}1${')' * 20}'), '1');
    });

    test('too many pending operators → Stack ERROR', () {
      expect(err('${'(' * 30}1'), CalcErrorKind.stack);
    });

    test('too many pending numbers → Stack ERROR', () {
      // 1+2×(3+4×(5+6×(... keeps numbers waiting on the stack.
      final s = List.generate(11, (i) => '${i + 1}+${i + 1}×(').join();
      expect(err('${s}1'), CalcErrorKind.stack);
    });
  });

  group('error position', () {
    test('points at the offending token', () {
      try {
        evaluate(t('1+2)'), ans: Dec.zero);
        fail('expected error');
      } on CalcError catch (e) {
        expect(e.position, 3);
      }
    });
  });
}
