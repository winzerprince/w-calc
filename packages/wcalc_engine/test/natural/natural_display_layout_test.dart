import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

void press(NaturalCalculator c, String seq) {
  for (final k in seq.split(' ')) {
    c.press(CalcKey.values.byName(k));
  }
}

bool anyLit(DotBitmap b, int x0, int x1, int y0, int y1) {
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      if (b.get(x, y)) return true;
    }
  }
  return false;
}

void main() {
  test('a fraction answer keeps the typed denominators whole', () {
    final c = NaturalCalculator();
    press(c, 'fraction d1 down d2 right add fraction d2 down d3 right equals');
    final dots = c.screen.dots;
    // The denominators 2 and 3 reach row 16 on the left …
    expect(anyLit(dots, 0, 30, 14, 16), isTrue);
    // … while the answer 7/6 is drawn at the right.
    expect(anyLit(dots, 85, 95, 24, 30), isTrue);
  });

  test('equation entry names the coefficient being typed', () {
    final c = NaturalCalculator();
    press(c, 'mode d5 d3');
    final a = c.screen.dots.toAscii().split('\n');
    press(c, 'd1 equals');
    final b = c.screen.dots.toAscii().split('\n');
    // Bottom-left label changes from a= to b=.
    String label(List<String> rows) =>
        [for (final r in rows.sublist(24, 31)) r.substring(0, 12)].join('\n');
    expect(label(a), isNot(label(b)));
    expect(anyLit(c.screen.dots, 0, 11, 24, 30), isTrue);
  });
}
