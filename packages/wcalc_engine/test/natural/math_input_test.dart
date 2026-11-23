import 'package:test/test.dart';
import 'package:wcalc_engine/src/eval/evaluator.dart';
import 'package:wcalc_engine/src/input/token.dart';
import 'package:wcalc_engine/src/natural/math_input.dart';
import 'package:wcalc_engine/src/number/dec.dart';
import 'package:wcalc_engine/src/number/value.dart';

void main() {
  late MathEditor ed;
  setUp(() => ed = MathEditor());

  void type(String s) {
    for (final c in s.split('')) {
      ed.insertTok(switch (c) {
        '+' => Tok.add,
        '-' => Tok.subtract,
        '*' => Tok.multiply,
        '/' => Tok.divide,
        '(' => Tok.openParen,
        ')' => Tok.closeParen,
        '.' => Tok.point,
        'X' => Tok.varX,
        _ => Tok.digits[int.parse(c)],
      });
    }
  }

  Value value() => evaluateValue(ed.linearize().tokens, EvalContext());
  String dec() => value().dec.toString();

  test('number then fraction key: 2 □/□ 3 ▶ + 1 □/□ 2 = 7/6', () {
    type('2');
    ed.insertTemplate(MathTemplate.fraction);
    expect(ed.cursor, const MathCursor([(0, 1)], 0)); // in the denominator
    type('3');
    ed.right();
    type('+1');
    ed.insertTemplate(MathTemplate.fraction);
    type('2');
    expect(ed.root.toString(), 'fraction{2|3}+fraction{1|2}');
    expect(value().frac.toString(), '7/6');
  });

  test('empty fraction template: □/□ 2 ▼ 3', () {
    ed.insertTemplate(MathTemplate.fraction);
    type('2');
    expect(ed.vertical(up: false), isTrue);
    type('3');
    expect(ed.root.toString(), 'fraction{2|3}');
  });

  test('mixed fraction 4 − 3½ = ½', () {
    type('4-');
    ed.insertTemplate(MathTemplate.mixed);
    type('3');
    ed.right();
    type('1');
    ed.right();
    type('2');
    expect(value().frac.toString(), '1/2');
  });

  test('√2 + √2 and (1+1)^(2+2) = 16', () {
    ed.insertTemplate(MathTemplate.sqrt);
    type('2');
    ed.right();
    type('+');
    ed.insertTemplate(MathTemplate.sqrt);
    type('2');
    expect(dec(), '2.8284271247462');
    ed.clear();
    type('(1+1)');
    ed.insertTemplate(MathTemplate.power);
    type('2+2');
    expect(dec(), '16');
  });

  test('log_2(16) = 4, ⁵√32 = 2', () {
    ed.insertTemplate(MathTemplate.logBase);
    type('2');
    ed.right();
    type('16');
    expect(dec(), '4');
    ed.clear();
    ed.insertTemplate(MathTemplate.root);
    type('5');
    ed.right();
    type('32');
    expect(dec(), '2');
  });

  test('Σ(X+1) for X = 1..5 is 20', () {
    ed.insertTemplate(MathTemplate.sum);
    type('X+1');
    ed.right();
    type('1');
    ed.right();
    type('5');
    expect(dec(), '20');
  });

  test('sin( needs no closing parenthesis before =', () {
    ed.insertTok(Tok.sin, paren: true);
    type('30');
    expect(dec(), '0.5');
  });

  test('▶ at the end wraps to the start, ◀ at the start to the end', () {
    type('12');
    ed.right();
    expect(ed.cursor, MathCursor.start);
    ed.left();
    expect(ed.cursor, const MathCursor([], 2));
  });

  test('cursor walks into and out of templates', () {
    type('1+');
    ed.insertTemplate(MathTemplate.fraction);
    type('2');
    ed.right(); // to denominator
    expect(ed.cursor, const MathCursor([(2, 1)], 0));
    ed.right(); // out
    expect(ed.cursor, const MathCursor([], 3));
    ed.left(); // back into the last slot
    expect(ed.cursor, const MathCursor([(2, 1)], 0));
    ed.left(); // previous slot end
    expect(ed.cursor, const MathCursor([(2, 0)], 1));
  });

  test('DEL at start of a template removes it but keeps the contents', () {
    ed.insertTemplate(MathTemplate.sqrt);
    type('49');
    ed.left();
    ed.left();
    expect(ed.cursor, const MathCursor([(0, 0)], 0));
    ed.delete();
    expect(ed.root.toString(), '49');
  });

  test('DEL deletes the character left of the cursor', () {
    type('123');
    ed.left();
    ed.delete();
    expect(ed.root.toString(), '13');
  });

  test('input stops at 99 bytes', () {
    for (var i = 0; i < 120; i++) {
      ed.insertTok(Tok.d1);
    }
    expect(ed.bytes, MathEditor.maxBytes);
  });

  test('error position maps back to the template', () {
    type('5+');
    ed.insertTemplate(MathTemplate.fraction);
    type('1');
    final form = ed.linearize();
    try {
      evaluateValue(form.tokens, EvalContext());
      fail('expected Syntax ERROR for empty denominator');
    } on CalcError catch (e) {
      expect(e.kind, CalcErrorKind.syntax);
      expect(form.cursorFor(e.position ?? 0, ed.cursor).path, isNotEmpty);
    }
  });

  test('values keep exact decimal arithmetic', () {
    type('0.1+0.2');
    expect(value().dec, Dec.parse('0.3'));
  });
}
