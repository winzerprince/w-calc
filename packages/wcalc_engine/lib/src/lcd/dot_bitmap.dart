import 'dot_font.dart';
import 'small_font.dart';

/// Monochrome dot matrix (row-major). The engine draws full-dot LCD screens
/// into it; the app only paints the lit dots.
final class DotBitmap {
  DotBitmap(this.width, this.height)
    : _dots = List.filled(width * height, false);

  final int width;
  final int height;
  final List<bool> _dots;

  bool operator [](({int x, int y}) p) => get(p.x, p.y);

  bool get(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && _dots[y * width + x];

  void set(int x, int y, [bool on = true]) {
    if (x >= 0 && y >= 0 && x < width && y < height) _dots[y * width + x] = on;
  }

  void clear() => _dots.fillRange(0, _dots.length, false);

  void hLine(int x0, int x1, int y) {
    for (var x = x0; x <= x1; x++) {
      set(x, y);
    }
  }

  void vLine(int x, int y0, int y1) {
    for (var y = y0; y <= y1; y++) {
      set(x, y);
    }
  }

  /// Draws rows of `#`/`.` with the top-left at (x, y).
  void blit(int x, int y, List<String> rows) {
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        if (row.codeUnitAt(c) == 0x23) set(x + c, y + r);
      }
    }
  }

  /// Normal 5×7 text, 6-dot pitch. Returns the x after the text.
  int text(int x, int y, String s) {
    for (final ch in s.runes.map(String.fromCharCode)) {
      blit(x, y, glyphFor(ch));
      x += dotFontWidth + 1;
    }
    return x;
  }

  /// Small 3×5 text, 4-dot pitch (falls back to the normal font).
  int smallText(int x, int y, String s) {
    for (final ch in s.runes.map(String.fromCharCode)) {
      final g = smallGlyphFor(ch);
      if (g != null) {
        blit(x, y, g);
        x += smallFontWidth + 1;
      } else {
        blit(x, y - 2, glyphFor(ch));
        x += dotFontWidth + 1;
      }
    }
    return x;
  }

  void invert(int x0, int y0, int x1, int y1) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, !get(x, y));
      }
    }
  }

  /// ASCII picture (`#` lit, `.` off) for tests and debugging.
  String toAscii({int? x0, int? x1}) {
    final b = StringBuffer();
    for (var y = 0; y < height; y++) {
      for (var x = x0 ?? 0; x < (x1 ?? width); x++) {
        b.write(get(x, y) ? '#' : '.');
      }
      if (y < height - 1) b.writeln();
    }
    return b.toString();
  }
}

/// Text width in dots (without the trailing gap).
int textWidth(String s) {
  final n = s.runes.length;
  return n == 0 ? 0 : n * (dotFontWidth + 1) - 1;
}

int smallTextWidth(String s) {
  var w = 0;
  for (final ch in s.runes.map(String.fromCharCode)) {
    w += smallGlyphFor(ch) != null ? smallFontWidth + 1 : dotFontWidth + 1;
  }
  return w == 0 ? 0 : w - 1;
}
