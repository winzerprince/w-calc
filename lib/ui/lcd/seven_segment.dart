/// Seven-segment character map for the result line.
///
/// Segments: a top, b top-right, c bottom-right, d bottom, e bottom-left,
/// f top-left, g middle.
library;

enum Segment { a, b, c, d, e, f, g }

const _s = Segment.values;

Set<Segment> _seg(String letters) => {
  for (final ch in letters.split('')) _s[ch.codeUnitAt(0) - 'a'.codeUnitAt(0)],
};

final Map<String, Set<Segment>> sevenSegmentMap = {
  '0': _seg('abcdef'),
  '1': _seg('bc'),
  '2': _seg('abged'),
  '3': _seg('abgcd'),
  '4': _seg('fgbc'),
  '5': _seg('afgcd'),
  '6': _seg('afgedc'),
  '7': _seg('abc'),
  '8': _seg('abcdefg'),
  '9': _seg('abcdfg'),
  '-': _seg('g'),
  ' ': <Segment>{},
  'A': _seg('abcefg'),
  'b': _seg('cdefg'),
  'C': _seg('adef'),
  'd': _seg('bcdeg'),
  'E': _seg('adefg'),
  'F': _seg('aefg'),
  'r': _seg('eg'),
  'o': _seg('cdeg'),
  // Fraction mark ⌟ and sexagesimal degree mark.
  '┘': _seg('cd'),
  '°': _seg('abfg'),
};

/// Segments for [char]; unknown characters light nothing.
Set<Segment> segmentsFor(String char) => sevenSegmentMap[char] ?? const {};

/// One digit cell of the result line. Every cell has a dot and a comma tail
/// after it; [point] lights the dot, [comma] lights dot + tail.
class SegmentCell {
  const SegmentCell(this.char, {this.point = false, this.comma = false});

  final String char;
  final bool point;
  final bool comma;

  SegmentCell withPoint() => SegmentCell(char, point: true, comma: comma);
  SegmentCell withComma() => SegmentCell(char, point: point, comma: true);
}

/// Splits a mantissa like `-1,234.5` into cells: `.` lights the dot after the
/// preceding digit, `,` lights dot + tail. The minus sign occupies its own cell.
List<SegmentCell> toCells(String mantissa) {
  final cells = <SegmentCell>[];
  for (final ch in mantissa.split('')) {
    if (ch == '.' || ch == ',') {
      if (cells.isEmpty) cells.add(const SegmentCell('0'));
      final last = cells.removeLast();
      cells.add(ch == '.' ? last.withPoint() : last.withComma());
    } else {
      cells.add(SegmentCell(ch));
    }
  }
  return cells;
}

/// Inserts 3-digit separators into the integer part (`1234567.5` → `1,234,567.5`).
/// Only plain decimal numbers are grouped; anything else is returned unchanged.
String groupDigits(String mantissa) {
  final m = RegExp(r'^(-?)(\d+)(\..*)?$').firstMatch(mantissa);
  if (m == null) return mantissa;
  final digits = m.group(2)!;
  final buf = StringBuffer(m.group(1) ?? "");
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  buf.write(m.group(3) ?? '');
  return buf.toString();
}
