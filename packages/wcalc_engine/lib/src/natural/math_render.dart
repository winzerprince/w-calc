import '../input/token.dart';
import '../lcd/dot_bitmap.dart';
import '../lcd/dot_font.dart';
import '../lcd/small_font.dart';
import 'math_input.dart';

/// Where the cursor is drawn: column [x], rows [top]..[top]+[height]-1.
final class CursorRect {
  const CursorRect(this.x, this.top, this.height);

  final int x;
  final int top;
  final int height;

  @override
  String toString() => 'CursorRect($x, $top, $height)';
}

/// Text size level: 0 = normal 5×7, 1 = script 3×5.
typedef _Level = int;

/// A laid-out piece of the expression. Coordinates are relative to its
/// baseline row: [above] rows over it, [below] rows under it.
abstract class _Box {
  int get width;
  int get above;
  int get below;
  int get height => above + 1 + below;

  /// Paints with the left edge at [x] and the baseline row at [y].
  void paint(_Painter p, int x, int y);
}

/// Paint context: the bitmap plus cursor tracking.
final class _Painter {
  _Painter(this.bmp, this.cursor);

  final DotBitmap bmp;
  final MathCursor? cursor;
  CursorRect? cursorRect;
}

int _glyphAbove(_Level l) => l == 0 ? dotFontHeight - 1 : smallFontHeight - 1;

/// Plain characters at one level.
final class _TextBox extends _Box {
  _TextBox(this.text, this.level);

  final String text;
  final _Level level;

  @override
  int get width => level == 0 ? textWidth(text) : smallTextWidth(text);
  @override
  int get above => _glyphAbove(level);
  @override
  int get below => 0;

  @override
  void paint(_Painter p, int x, int y) {
    final top = y - above;
    if (level == 0) {
      p.bmp.text(x, top, text);
    } else {
      p.bmp.smallText(x, top, text);
    }
  }
}

/// Dotted outline marking an empty slot.
final class _EmptyBox extends _Box {
  _EmptyBox(this.level);

  final _Level level;

  @override
  int get width => level == 0 ? 5 : 3;
  @override
  int get above => _glyphAbove(level);
  @override
  int get below => 0;

  @override
  void paint(_Painter p, int x, int y) {
    final top = y - above, w = width, h = above + 1;
    for (var i = 0; i < w; i += 2) {
      p.bmp
        ..set(x + i, top)
        ..set(x + i, top + h - 1);
    }
    for (var j = 0; j < h; j += 2) {
      p.bmp
        ..set(x, top + j)
        ..set(x + w - 1, top + j);
    }
  }
}

/// A row: children side by side with 1 dot between them; tracks the cursor.
final class _RowBox extends _Box {
  _RowBox(this.children, this.path, this.level, {required this.empty});

  final List<_Box> children;
  final List<(int, int)> path;
  final _Level level;
  final bool empty;

  @override
  int get width {
    if (children.isEmpty) return 0;
    var w = 0;
    for (final c in children) {
      w += c.width;
    }
    return w + children.length - 1;
  }

  @override
  int get above =>
      children.fold(_glyphAbove(level), (m, c) => c.above > m ? c.above : m);
  @override
  int get below => children.fold(0, (m, c) => c.below > m ? c.below : m);

  bool _isCursorRow(MathCursor? c) {
    if (c == null || c.path.length != path.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (c.path[i] != path[i]) return false;
    }
    return true;
  }

  @override
  void paint(_Painter p, int x, int y) {
    final hasCursor = _isCursorRow(p.cursor);
    final h = _glyphAbove(level) + 1;
    void mark(int cx) {
      p.cursorRect = CursorRect(cx, y - h + 1, h);
    }

    var cx = x;
    // `empty` rows hold a single placeholder child (the dotted box).
    for (var i = 0; i < children.length; i++) {
      if (hasCursor && !empty && p.cursor!.pos == i) {
        mark(cx == x ? cx : cx - 1);
      }
      children[i].paint(p, cx, y);
      cx += children[i].width + 1;
    }
    if (hasCursor && (empty || p.cursor!.pos == children.length)) {
      mark(empty ? x : cx - 1);
    }
  }
}

/// Stacked fraction: numerator over a bar over the denominator.
final class _FractionBox extends _Box {
  _FractionBox(this.num, this.den, this.level);

  final _Box num;
  final _Box den;
  final _Level level;

  int get _bar => level == 0 ? 3 : 2; // bar rows above the baseline

  @override
  int get width => (num.width > den.width ? num.width : den.width) + 2;
  @override
  int get above => _bar + 2 + num.below + num.above;
  @override
  int get below {
    final b = den.above + den.below + 2 - _bar;
    return b < 0 ? 0 : b;
  }

  @override
  void paint(_Painter p, int x, int y) {
    final barY = y - _bar;
    p.bmp.hLine(x, x + width - 1, barY);
    num.paint(p, x + (width - num.width) ~/ 2, barY - 2 - num.below);
    den.paint(p, x + (width - den.width) ~/ 2, barY + 2 + den.above);
  }
}

/// Radical with an overline; optional small index (ˣ√, ∛).
final class _RootBox extends _Box {
  _RootBox(this.content, this.index);

  final _Box content;
  final _Box? index;

  int get _indexW =>
      index == null ? 0 : (index!.width > 2 ? index!.width - 2 : 0);

  @override
  int get width => _indexW + 4 + content.width + 1;
  @override
  int get above {
    final a = content.above + 2;
    final i = index == null ? 0 : index!.height + 1;
    return a > i ? a : i;
  }

  @override
  int get below => content.below;

  @override
  void paint(_Painter p, int x, int y) {
    final top = y - content.above - 2;
    final bottom = y + content.below;
    final sx = x + _indexW;
    // Tick: a short rise, the long stroke down-up, then the overline.
    p.bmp
      ..set(sx, bottom - 2)
      ..set(sx + 1, bottom - 1)
      ..set(sx + 1, bottom);
    p.bmp.vLine(sx + 2, top, bottom);
    p.bmp.hLine(sx + 2, sx + 4 + content.width, top);
    if (index != null) {
      index!.paint(p, x, bottom - 3 - index!.below);
    }
    content.paint(p, sx + 4, y);
  }
}

/// Base raised exponent (x^□, 10^□, e^□): [base] may be null (attached to
/// the previous item).
final class _SuperBox extends _Box {
  _SuperBox(this.base, this.exponent, this.level);

  final _Box? base;
  final _Box exponent;
  final _Level level;

  int get _raise => level == 0 ? 4 : 3;
  int get _baseW => base == null ? 0 : base!.width + 1;

  @override
  int get width => _baseW + exponent.width;
  @override
  int get above {
    final e = _raise + exponent.above;
    final b = base?.above ?? _glyphAbove(level);
    return e > b ? e : b;
  }

  @override
  int get below {
    final e = exponent.below - _raise;
    final b = base?.below ?? 0;
    return e > b ? e : (b < 0 ? 0 : b);
  }

  @override
  void paint(_Painter p, int x, int y) {
    base?.paint(p, x, y);
    exponent.paint(p, x + _baseW, y - _raise);
  }
}

/// |content| with bars as tall as the content.
final class _AbsBox extends _Box {
  _AbsBox(this.content);

  final _Box content;

  @override
  int get width => content.width + 4;
  @override
  int get above => content.above + 1;
  @override
  int get below => content.below + 1;

  @override
  void paint(_Painter p, int x, int y) {
    p.bmp
      ..vLine(x, y - above, y + below)
      ..vLine(x + width - 1, y - above, y + below);
    content.paint(p, x + 2, y);
  }
}

/// Horizontal sequence of boxes without the 1-dot row gaps (glued parts).
final class _SeqBox extends _Box {
  _SeqBox(this.parts, {this.gap = 1});

  final List<_Box> parts;
  final int gap;

  @override
  int get width {
    var w = 0;
    for (final b in parts) {
      w += b.width;
    }
    return w + gap * (parts.length - 1);
  }

  @override
  int get above => parts.fold(0, (m, c) => c.above > m ? c.above : m);
  @override
  int get below => parts.fold(0, (m, c) => c.below > m ? c.below : m);

  @override
  void paint(_Painter p, int x, int y) {
    for (final b in parts) {
      b.paint(p, x, y);
      x += b.width + gap;
    }
  }
}

/// Box placed with an offset baseline (subscripts, limits).
final class _ShiftBox extends _Box {
  _ShiftBox(this.inner, this.dy);

  final _Box inner;

  /// Positive = lower.
  final int dy;

  @override
  int get width => inner.width;
  @override
  int get above {
    final a = inner.above - dy;
    return a < 0 ? 0 : a;
  }

  @override
  int get below {
    final b = inner.below + dy;
    return b < 0 ? 0 : b;
  }

  @override
  void paint(_Painter p, int x, int y) => inner.paint(p, x, y + dy);
}

/// Big operator (∫, Σ) with limits stacked to its right (∫) or above and
/// below (Σ).
final class _BigOpBox extends _Box {
  _BigOpBox(this.symbol, this.lower, this.upper, {required this.side});

  /// 'int' or 'sum'.
  final String symbol;
  final _Box lower;
  final _Box upper;
  final bool side;

  static const _intAbove = 8, _intBelow = 3;

  int get _symW => symbol == 'int' ? 4 : 5;

  @override
  int get width {
    if (side) {
      final l = lower.width > upper.width ? lower.width : upper.width;
      return _symW + 1 + l;
    }
    final m = [_symW, lower.width, upper.width].reduce((a, b) => a > b ? a : b);
    return m;
  }

  @override
  int get above => side
      ? (_intAbove > upper.height - 2 + 4 ? _intAbove : upper.height + 2)
      : 6 + 1 + upper.height;

  @override
  int get below => side ? _intBelow + 1 : lower.height + 1;

  @override
  void paint(_Painter p, int x, int y) {
    if (side) {
      // Tall integral sign.
      final top = y - _intAbove, bottom = y + _intBelow;
      p.bmp
        ..set(x + 3, top)
        ..set(x + 2, top + 1)
        ..vLine(x + 2, top + 1, bottom - 1)
        ..set(x + 1, bottom)
        ..set(x, bottom - 1);
      upper.paint(p, x + _symW + 1, top + upper.above);
      lower.paint(p, x + _symW + 1, bottom + 1 - lower.below);
      return;
    }
    final cx = x + (width - _symW) ~/ 2;
    p.bmp.blit(cx, y - 6, glyphFor('Σ'));
    upper.paint(p, x + (width - upper.width) ~/ 2, y - 8 - upper.below);
    lower.paint(p, x + (width - lower.width) ~/ 2, y + 2 + lower.above);
  }
}

/// Lays out a [MathRow] for painting.
final class MathLayout {
  /// [symbols] replaces how tokens are written (e.g. `/` for ÷ on models
  /// that show division that way).
  MathLayout(MathRow root, {Map<Tok, String> symbols = const {}})
    : _box = _build(root, symbols);

  static Map<Tok, String> _symbols = const {};

  static _Box _build(MathRow root, Map<Tok, String> symbols) {
    final saved = _symbols;
    _symbols = symbols;
    try {
      return _row(root, const [], 0);
    } finally {
      _symbols = saved;
    }
  }

  final _Box _box;

  int get width => _box.width;
  int get above => _box.above;
  int get below => _box.below;
  int get height => _box.height;

  /// Paints with the top-left at (x, top); returns the cursor rectangle when
  /// [cursor] is inside the expression.
  CursorRect? paint(DotBitmap bmp, int x, int top, {MathCursor? cursor}) {
    final p = _Painter(bmp, cursor);
    _box.paint(p, x, top + _box.above);
    return p.cursorRect;
  }

  static _Box _row(MathRow r, List<(int, int)> path, _Level level) {
    if (r.isEmpty && path.isNotEmpty) {
      return _RowBox([_EmptyBox(level)], path, level, empty: true);
    }
    final children = <_Box>[];
    for (var i = 0; i < r.items.length; i++) {
      final item = r.items[i];
      children.add(switch (item) {
        TokItem() => _TextBox(_tokText(item), level),
        TemplateItem() => _template(item, [...path, (i, 0)], level),
      });
    }
    return _RowBox(children, path, level, empty: false);
  }

  static String _tokText(TokItem t) {
    final s =
        _symbols[t.tok] ??
        switch (t.tok) {
          Tok.negative => '-',
          Tok.fracSep => '⌟',
          Tok.percentOf => '%',
          _ => t.tok.text.trimRight(),
        };
    if (t.paren && t.tok.kind != TokKind.function) return '$s(';
    return s;
  }

  static _Box _template(
    TemplateItem t,
    List<(int, int)> firstSlot,
    _Level level,
  ) {
    final base = firstSlot.sublist(0, firstSlot.length - 1);
    final item = firstSlot.last.$1;
    _Box slot(int s, [_Level? l]) =>
        _row(t.slots[s], [...base, (item, s)], l ?? level);
    final small = level == 0 ? 1 : 1;
    _Box text(String s, [_Level? l]) => _TextBox(s, l ?? level);
    return switch (t.kind) {
      MathTemplate.fraction => _FractionBox(slot(0), slot(1), level),
      MathTemplate.mixed => _SeqBox([
        slot(0),
        _FractionBox(slot(1), slot(2), level),
      ]),
      MathTemplate.sqrt => _RootBox(slot(0), null),
      MathTemplate.cbrt => _RootBox(slot(0), text('3', small)),
      MathTemplate.root => _RootBox(slot(1), slot(0, small)),
      MathTemplate.power => _SuperBox(null, slot(0, small), level),
      MathTemplate.tenPow => _SuperBox(text('10'), slot(0, small), level),
      MathTemplate.ePow => _SuperBox(text('e'), slot(0, small), level),
      MathTemplate.abs => _AbsBox(slot(0)),
      MathTemplate.logBase => _SeqBox([
        text('log'),
        _ShiftBox(slot(0, small), 2),
        text('('),
        slot(1),
        text(')'),
      ]),
      MathTemplate.integral => _SeqBox([
        _BigOpBox('int', slot(1, small), slot(2, small), side: true),
        slot(0),
        text('dx'),
      ]),
      MathTemplate.derivative => _SeqBox([
        _FractionBox(text('d'), text('dx'), level),
        text('('),
        slot(0),
        text(')'),
        _ShiftBox(_SeqBox([text('x=', small), slot(1, small)], gap: 1), 3),
      ]),
      MathTemplate.sum => _SeqBox([
        _BigOpBox(
          'sum',
          _SeqBox([text('x=', small), slot(1, small)]),
          slot(2, small),
          side: false,
        ),
        text('('),
        slot(0),
        text(')'),
      ]),
    };
  }
}
