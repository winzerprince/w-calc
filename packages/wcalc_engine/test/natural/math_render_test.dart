import 'package:test/test.dart';
import 'package:wcalc_engine/src/input/token.dart';
import 'package:wcalc_engine/src/lcd/dot_bitmap.dart';
import 'package:wcalc_engine/src/natural/math_input.dart';
import 'package:wcalc_engine/src/natural/math_render.dart';

void main() {
  late MathEditor ed;
  setUp(() => ed = MathEditor());

  void type(String s) {
    for (final ch in s.split('')) {
      ed.insertTok(switch (ch) {
        '+' => Tok.add,
        'X' => Tok.varX,
        _ => Tok.digits[int.parse(ch)],
      });
    }
  }

  (String, CursorRect?) render({int cols = 24, int rows = 17}) {
    final bmp = DotBitmap(96, 31);
    final c = MathLayout(ed.root).paint(bmp, 0, 0, cursor: ed.cursor);
    final ascii = bmp.toAscii(x1: cols).split('\n').take(rows).join('\n');
    return (ascii, c);
  }

  test('2/3 is a stacked fraction with the bar 3 rows over the baseline', () {
    type('2');
    ed.insertTemplate(MathTemplate.fraction);
    type('3');
    final (ascii, cursor) = render(cols: 7);
    expect(
      ascii,
      [
        '..###..',
        '.#...#.',
        '.....#.',
        '....#..',
        '...#...',
        '..#....',
        '.#####.',
        '.......',
        '#######',
        '.......',
        '.#####.',
        '....#..',
        '...#...',
        '....#..',
        '.....#.',
        '.#...#.',
        '..###..',
      ].join('\n'),
    );
    // Cursor at the end of the denominator.
    expect(cursor.toString(), 'CursorRect(6, 10, 7)');
  });

  test('plain text sits on a 6-dot pitch', () {
    type('12');
    final m = MathLayout(ed.root);
    expect(m.width, 11);
    expect(m.height, 7);
  });

  test('every template lays out inside two screens and paints', () {
    for (final t in MathTemplate.values) {
      ed.clear();
      ed.insertTemplate(t);
      type('1');
      final m = MathLayout(ed.root);
      expect(m.height, lessThanOrEqualTo(62), reason: t.name);
      expect(m.width, greaterThan(0), reason: t.name);
      final bmp = DotBitmap(96, 62);
      final c = m.paint(bmp, 0, 0, cursor: ed.cursor);
      expect(c, isNotNull, reason: '${t.name} cursor');
      expect(bmp.toAscii().contains('#'), isTrue, reason: t.name);
    }
  });

  test('nested fractions grow upward and downward', () {
    ed.insertTemplate(MathTemplate.fraction);
    ed.insertTemplate(MathTemplate.fraction);
    type('1');
    ed.right();
    type('2');
    ed.right();
    ed.right();
    type('3');
    final m = MathLayout(ed.root);
    expect(m.height, greaterThan(17));
  });

  test('empty slot shows a dotted box and holds the cursor', () {
    ed.insertTemplate(MathTemplate.sqrt);
    final (_, cursor) = render();
    expect(cursor, isNotNull);
  });
}
