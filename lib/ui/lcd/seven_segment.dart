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
};

/// Segments for [char]; unknown characters light nothing.
Set<Segment> segmentsFor(String char) => sevenSegmentMap[char] ?? const {};

/// One digit cell of the result line.
class SegmentCell {
  const SegmentCell(this.char, {this.point = false});

  final String char;

  /// Decimal point lit after this digit.
  final bool point;
}

/// Splits a mantissa like `-6.666666667` into cells; points attach to the
/// preceding digit. The minus sign occupies its own cell.
List<SegmentCell> toCells(String mantissa) {
  final cells = <SegmentCell>[];
  for (final ch in mantissa.split('')) {
    if (ch == '.' || ch == ',') {
      if (cells.isEmpty) {
        cells.add(const SegmentCell('0', point: true));
      } else {
        cells[cells.length - 1] = SegmentCell(cells.last.char, point: true);
      }
    } else {
      cells.add(SegmentCell(ch));
    }
  }
  return cells;
}
