import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void main() {
  GraphFunction g(String s, {AngleUnit angle = AngleUnit.rad}) =>
      GraphFunction(parseFormula(s), angle: angle);

  test('parses typed formulas', () {
    expect(g('x^2-1').at(3), 8);
    expect(g('y = 2x + 1').at(2), 5);
    expect(g('2sin(x)').at(0), 0);
    expect(g('sqrt(x)+1/x').at(4), closeTo(2.25, 1e-12));
    expect(g('-x^2').at(3), -9);
    expect(g('x(x+1)').at(2), 6);
    expect(g('ln(e)').at(0), closeTo(1, 1e-12));
    expect(g('3!').at(0), 6);
    expect(() => parseFormula('x ? 2'), throwsFormatException);
  });

  test('fast path for common functions, exact fallback otherwise', () {
    expect(g('sin(x)^2+cos(x)^2').isFast, isTrue);
    final integral = GraphFunction([
      Tok.integral,
      Tok.varX,
      Tok.comma,
      Tok.d0,
      Tok.comma,
      Tok.d1,
      Tok.closeParen,
    ]);
    expect(integral.isFast, isFalse);
    expect(integral.at(5), closeTo(0.5, 1e-9));
  });

  test('gaps where undefined', () {
    expect(g('sqrt(x)').at(-1), isNull);
    expect(g('1/x').at(0), isNull);
  });

  test('degrees follow the angle unit', () {
    expect(g('sin(x)', angle: AngleUnit.deg).at(30), closeTo(0.5, 1e-12));
  });

  test('roots and extrema', () {
    final f = g('x^2-4');
    expect(f.roots(-10, 10).map((r) => r.toStringAsFixed(6)), [
      '-2.000000',
      '2.000000',
    ]);
    final ext = f.extrema(-10, 10);
    expect(ext, hasLength(1));
    expect(ext.single.$1, closeTo(0, 1e-6));
    expect(ext.single.$3, isFalse); // minimum
    // 1/x changes sign at 0 but has no root there.
    expect(g('1/x').roots(-1, 1), isEmpty);
  });

  test('odd roots of negatives stay real', () {
    expect(g('cbrt(x)').at(-8), closeTo(-2, 1e-12));
  });

  test('intersections of x² and 2x + 3: (−1, 1) and (3, 9)', () {
    final pts = intersections(g('x^2'), g('2x+3'), -10, 10);
    expect(
      pts.map((p) => '${p.x.toStringAsFixed(4)},${p.y.toStringAsFixed(4)}'),
      ['-1.0000,1.0000', '3.0000,9.0000'],
    );
  });

  test('more syntax: pi, ×, ², ., roots of degrees', () {
    expect(g('pi×x²').at(1), closeTo(3.14159265, 1e-8));
    expect(g('0.5x').at(4), 2);
    expect(g('asin(x)', angle: AngleUnit.deg).at(1), closeTo(90, 1e-9));
    expect(g('x^(1/3)').at(-8), closeTo(-2, 1e-9));
    final xr = GraphFunction([Tok.d3, Tok.xRoot, Tok.varX]);
    expect(xr.at(-27), closeTo(-3, 1e-9));
  });
}
