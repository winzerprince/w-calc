import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// A laid-out piece of maths. Coordinates are relative to the left end of
/// its baseline; [ascent] is above it, [descent] below.
class _Piece {
  _Piece(this.width, this.ascent, this.descent);

  double width;
  double ascent;
  double descent;
  final List<void Function(Canvas, Offset)> _ops = [];

  /// Caret rectangles by cursor position.
  final Map<GxCursor, Rect> carets = {};

  double get height => ascent + descent;

  void draw(void Function(Canvas, Offset) op) => _ops.add(op);

  void place(_Piece child, double dx, double dy) {
    _ops.add((c, o) => child.paint(c, o + Offset(dx, dy)));
    child.carets.forEach((k, r) => carets[k] = r.shift(Offset(dx, dy)));
  }

  void paint(Canvas c, Offset o) {
    for (final op in _ops) {
      op(c, o);
    }
  }
}

const _binary = {'+', '-', '×', '÷', '=', '<', '>', '≤', '≥'};

/// Typesets a [GxRow] the way maths is written: fractions stacked, powers
/// raised, roots drawn, brackets grown to fit.
class GxTypeset {
  GxTypeset(this.row, {required this.size, required this.color})
    : _root = _Piece(0, 0, 0) {
    final p = _row(row, const [], size);
    _root
      ..width = p.width
      ..ascent = p.ascent
      ..descent = p.descent
      ..place(p, 0, 0);
  }

  final GxRow row;
  final double size;
  final Color color;
  final _Piece _root;

  Size get extent => Size(_root.width, _root.height);
  double get baseline => _root.ascent;

  /// Caret rectangle for [c] in widget coordinates.
  Rect? caret(GxCursor c) => _root.carets[c]?.shift(Offset(0, _root.ascent));

  /// The caret position nearest to [p].
  GxCursor nearest(Offset p) {
    GxCursor? best;
    var bestD = double.infinity;
    _root.carets.forEach((k, r0) {
      final r = r0.shift(Offset(0, _root.ascent));
      final dy = p.dy < r.top
          ? r.top - p.dy
          : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
      final d = (r.left - p.dx).abs() + dy * 2;
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    });
    return best ?? GxCursor(const [], row.items.length);
  }

  void paint(Canvas canvas, Offset offset) =>
      _root.paint(canvas, offset + Offset(0, _root.ascent));

  // ── text ────────────────────────────────────────────────────────────

  _Piece _text(String text, double size, {bool italic = false, Color? tint}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'serif',
          fontFamilyFallback: const ['WCalcSymbols'],
          fontSize: size,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: tint ?? color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final asc = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final p = _Piece(
      tp.width + (italic ? size * 0.04 : 0),
      asc,
      tp.height - asc,
    );
    p.draw((c, o) => tp.paint(c, o - Offset(0, asc)));
    return p;
  }

  /// Axis of fractions and the middle of + and − above the baseline.
  double _axis(double size) => size * 0.3;

  // ── rows ────────────────────────────────────────────────────────────

  _Piece _row(GxRow r, List<(int, int)> path, double size) {
    final items = r.items;
    final pieces = List<_Piece?>.filled(items.length, null);
    final out = _Piece(0, size * 0.7, size * 0.22);

    if (items.isEmpty) {
      // Empty slot: a faint box to fill.
      if (path.isNotEmpty) {
        final w = size * 0.55, h = size * 0.75;
        out
          ..width = w
          ..ascent = h - size * 0.05
          ..descent = size * 0.05
          ..draw(
            (c, o) => c.drawRect(
              Rect.fromLTWH(o.dx + 1, o.dy - h + size * 0.05, w - 2, h),
              Paint()
                ..color = color.withValues(alpha: 0.28)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            ),
          );
      }
      out.carets[GxCursor(path, 0)] = _caretRect(
        out.width / 2 - 0.75,
        out,
        size,
      );
      return out;
    }

    // Everything except brackets and raised boxes first.
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is GxSym && (it.text == '(' || it.text == ')')) continue;
      if (it is GxBox && (it.kind == GxKind.pow || it.kind == GxKind.sub)) {
        continue;
      }
      pieces[i] = _item(it, i, items, [...path], size);
    }

    // Brackets grow to what they enclose.
    final stack = <int>[];
    final spans = <int, (double, double)>{};
    for (var i = 0; i < items.length; i++) {
      if (items[i] == const GxSym('(')) stack.add(i);
      if (items[i] == const GxSym(')') && stack.isNotEmpty) {
        final open = stack.removeLast();
        var a = size * 0.7, d = size * 0.22;
        for (var k = open + 1; k < i; k++) {
          final p = pieces[k];
          if (p != null) {
            a = math.max(a, p.ascent);
            d = math.max(d, p.descent);
          }
        }
        spans[open] = spans[i] = (a, d);
      }
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is GxSym && (it.text == '(' || it.text == ')')) {
        final (a, d) = spans[i] ?? (size * 0.7, size * 0.22);
        pieces[i] = _paren(it.text == '(', a, d, size, faint: spans[i] == null);
      }
    }

    // Lay out left to right; powers and subscripts sit on what precedes.
    var x = 0.0;
    _Piece? prev;
    for (var i = 0; i < items.length; i++) {
      out.carets[GxCursor(path, i)] = _caretRect(x, out, size);
      final it = items[i];
      if (it case GxBox(kind: GxKind.pow || GxKind.sub, :final slots)) {
        final small = math.max(size * 0.7, 9.0);
        final child = _row(slots[0], [...path, (i, 0)], small);
        final pow = it.kind == GxKind.pow;
        final shift = pow
            ? math.max(
                size * 0.42,
                (prev?.ascent ?? size * 0.7) - child.ascent * 0.55,
              )
            : -size * 0.22 - math.max(0, child.ascent - small * 0.7) * 0.5;
        final p = _Piece(child.width + size * 0.04, 0, 0)
          ..ascent = math.max(0, shift + child.ascent)
          ..descent = math.max(0, child.descent - shift)
          ..place(child, size * 0.02, -shift);
        pieces[i] = p;
      }
      final p = pieces[i]!;
      out.place(p, x, 0);
      x += p.width;
      out
        ..ascent = math.max(out.ascent, p.ascent)
        ..descent = math.max(out.descent, p.descent);
      prev = p;
    }
    out.width = x;
    out.carets[GxCursor(path, items.length)] = _caretRect(x, out, size);
    // Carets span the row's height.
    for (final k in out.carets.keys.toList()) {
      if (k.path.length == path.length && _samePath(k.path, path)) {
        final r = out.carets[k]!;
        out.carets[k] = Rect.fromLTRB(
          r.left,
          -math.max(out.ascent, size * 0.75),
          r.left + 1.6,
          math.max(out.descent, size * 0.22),
        );
      }
    }
    return out;
  }

  static bool _samePath(List<(int, int)> a, List<(int, int)> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Rect _caretRect(double x, _Piece row, double size) =>
      Rect.fromLTRB(x, -size * 0.75, x + 1.6, size * 0.22);

  _Piece _item(
    GxNode it,
    int i,
    List<GxNode> items,
    List<(int, int)> path,
    double size,
  ) {
    switch (it) {
      case GxSym(:final text):
        if (it.isWord) {
          // Inverse functions read sin⁻¹, with the −1 raised.
          final inverse = text.startsWith('arc');
          final w = _text(inverse ? text.substring(3) : text, size);
          final sup = inverse ? _text('−1', size * 0.62) : null;
          final supW = sup?.width ?? 0;
          final p = _Piece(w.width + supW + size * 0.12, w.ascent, w.descent)
            ..place(w, size * 0.04, 0);
          if (sup != null) {
            p
              ..place(sup, size * 0.04 + w.width, -size * 0.42)
              ..ascent = math.max(w.ascent, size * 0.42 + sup.ascent);
          }
          return p;
        }
        if (_binary.contains(text)) {
          final prevItem = i > 0 ? items[i - 1] : null;
          final unary =
              (text == '-' || text == '+') &&
              (prevItem == null ||
                  prevItem is GxSym &&
                      (_binary.contains(prevItem.text) ||
                          prevItem.text == '(' ||
                          prevItem.text == ','));
          final glyph = text == '≤' || text == '≥'
              ? _lessEq(text == '≤', size)
              : _text(text == '-' ? '−' : text, size);
          final pad = unary ? size * 0.04 : size * 0.2;
          final p = _Piece(glyph.width + 2 * pad, glyph.ascent, glyph.descent)
            ..place(glyph, pad, 0);
          return p;
        }
        if (text == ',') {
          final g = _text(',', size);
          return _Piece(g.width + size * 0.25, g.ascent, g.descent)
            ..place(g, 0, 0);
        }
        return _text(text, size, italic: it.isLetter);
      case GxBox(:final kind, :final slots):
        List<(int, int)> slot(int s) => [...path, (i, s)];
        return switch (kind) {
          GxKind.frac => _frac(
            _row(slots[0], slot(0), _inner(size)),
            _row(slots[1], slot(1), _inner(size)),
            size,
          ),
          GxKind.sqrt => _radical(_row(slots[0], slot(0), size), null, size),
          GxKind.root => _radical(
            _row(slots[1], slot(1), size),
            _row(slots[0], slot(0), math.max(size * 0.5, 8)),
            size,
          ),
          GxKind.abs => _bars(_row(slots[0], slot(0), size), size),
          GxKind.sum || GxKind.prod => _bigOp(
            kind == GxKind.sum ? 'Σ' : 'Π',
            _row(slots[0], slot(0), size * 0.62),
            _row(slots[1], slot(1), size * 0.62),
            _row(slots[2], slot(2), size),
            size,
          ),
          GxKind.integral => _integral(
            _row(slots[0], slot(0), size * 0.62),
            _row(slots[1], slot(1), size * 0.62),
            _row(slots[2], slot(2), size),
            _row(slots[3], slot(3), size),
            size,
          ),
          GxKind.deriv => _deriv(_row(slots[0], slot(0), size), size),
          GxKind.pow || GxKind.sub => _Piece(0, 0, 0),
        };
    }
  }

  double _inner(double size) => math.max(size * 0.9, 10);

  /// ≤ / ≥ drawn (not every font has them).
  _Piece _lessEq(bool less, double size) {
    final w = size * 0.55, axis = _axis(size);
    final p = _Piece(w, axis + size * 0.26, size * 0.02);
    p.draw((c, o) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = math.max(1, size * 0.06)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final l = o.dx + size * 0.04, r = o.dx + w - size * 0.04;
      final top = o.dy - axis - size * 0.24, mid = o.dy - axis + size * 0.02;
      final bottom = o.dy - axis + size * 0.24 - size * 0.1;
      final tip = less ? l : r, end = less ? r : l;
      c.drawPath(
        Path()
          ..moveTo(end, top)
          ..lineTo(tip, (top + bottom) / 2 - size * 0.04)
          ..lineTo(end, bottom - size * 0.04),
        paint,
      );
      c.drawLine(
        Offset(l, mid + size * 0.2),
        Offset(r, mid + size * 0.2),
        paint,
      );
    });
    return p;
  }

  // ── boxes ───────────────────────────────────────────────────────────

  _Piece _frac(_Piece num, _Piece den, double size) {
    final pad = size * 0.12, gap = size * 0.12, axis = _axis(size);
    final w = math.max(num.width, den.width) + 2 * pad;
    final p = _Piece(w + size * 0.08, axis + gap + num.height, 0)
      ..descent = math.max(0, den.height + gap - axis);
    p
      ..place(
        num,
        size * 0.04 + (w - num.width) / 2,
        -(axis + gap + num.descent),
      )
      ..place(den, size * 0.04 + (w - den.width) / 2, -axis + gap + den.ascent)
      ..draw(
        (c, o) => c.drawLine(
          o + Offset(size * 0.04, -axis),
          o + Offset(size * 0.04 + w, -axis),
          Paint()
            ..color = color
            ..strokeWidth = math.max(1, size * 0.055),
        ),
      );
    return p;
  }

  _Piece _radical(_Piece body, _Piece? index, double size) {
    final top = body.ascent + size * 0.14;
    final hook = size * 0.55;
    final lead = index == null ? 0.0 : math.max(0.0, index.width - hook * 0.45);
    final p = _Piece(
      lead + hook + body.width + size * 0.12,
      top + size * 0.06,
      body.descent + size * 0.04,
    );
    p.place(body, lead + hook, 0);
    p.draw((c, o) {
      final b = o + Offset(lead, 0);
      final path = Path()
        ..moveTo(b.dx, b.dy - top * 0.42)
        ..lineTo(b.dx + hook * 0.22, b.dy - top * 0.5)
        ..lineTo(b.dx + hook * 0.5, b.dy + body.descent)
        ..lineTo(b.dx + hook * 0.92, b.dy - top)
        ..lineTo(b.dx + hook + body.width + size * 0.08, b.dy - top);
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size * 0.055)
          ..strokeJoin = StrokeJoin.round,
      );
    });
    if (index != null) {
      p
        ..ascent = math.max(p.ascent, top * 0.5 + index.height)
        ..place(index, 0, -(top * 0.48 + index.descent));
    }
    return p;
  }

  _Piece _bars(_Piece body, double size) {
    final pad = size * 0.14;
    final p = _Piece(
      body.width + 4 * pad,
      body.ascent + size * 0.06,
      body.descent + size * 0.06,
    );
    p.place(body, 2 * pad, 0);
    p.draw((c, o) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = math.max(1, size * 0.06);
      for (final x in [pad, p.width - pad]) {
        c.drawLine(o + Offset(x, -p.ascent), o + Offset(x, p.descent), paint);
      }
    });
    return p;
  }

  _Piece _paren(
    bool open,
    double a,
    double d,
    double size, {
    bool faint = false,
  }) {
    final h = a + d;
    final w = size * 0.32 + h * 0.04;
    final p = _Piece(w, a + size * 0.04, d + size * 0.04);
    p.draw((c, o) {
      final x0 = o.dx + (open ? w * 0.75 : w * 0.25);
      final x1 = o.dx + (open ? w * 0.2 : w * 0.8);
      final path = Path()
        ..moveTo(x0, o.dy - a)
        ..quadraticBezierTo(
          x1 - (x0 - x1) * 0.25,
          o.dy + (d - a) / 2,
          x0,
          o.dy + d,
        );
      c.drawPath(
        path,
        Paint()
          ..color = faint ? color.withValues(alpha: 0.4) : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size * 0.06)
          ..strokeCap = StrokeCap.round,
      );
    });
    return p;
  }

  _Piece _bigOp(
    String sym,
    _Piece lower,
    _Piece upper,
    _Piece body,
    double size,
  ) {
    final g = _text(sym, size * 1.35);
    final colW = [g.width, lower.width, upper.width].reduce(math.max);
    final axis = _axis(size);
    final gTop = axis + g.height / 2, gBottom = g.height / 2 - axis;
    final p = _Piece(colW + size * 0.15 + body.width + size * 0.08, 0, 0);
    p
      ..place(g, (colW - g.width) / 2, -axis + g.height / 2 - g.descent)
      ..place(upper, (colW - upper.width) / 2, -(gTop + upper.descent + 2))
      ..place(lower, (colW - lower.width) / 2, gBottom + lower.ascent + 2)
      ..place(body, colW + size * 0.15, 0)
      ..ascent = math.max(body.ascent, gTop + upper.height + 2)
      ..descent = math.max(body.descent, gBottom + lower.height + 2);
    return p;
  }

  _Piece _integral(
    _Piece lower,
    _Piece upper,
    _Piece body,
    _Piece variable,
    double size,
  ) {
    final g = _text('∫', size * 1.6, italic: false);
    final axis = _axis(size);
    final gTop = axis + g.height / 2, gBottom = g.height / 2 - axis;
    final limW = math.max(lower.width, upper.width);
    final d = _text('d', size);
    final p = _Piece(0, 0, 0);
    var x = 0.0;
    p.place(g, x, -axis + g.height / 2 - g.descent);
    x += g.width * 0.8;
    p
      ..place(upper, x + size * 0.18, -(gTop + upper.descent * 0.2))
      ..place(lower, x - size * 0.12, gBottom - lower.descent);
    x += limW + size * 0.15;
    p.place(body, x, 0);
    x += body.width + size * 0.16;
    p.place(d, x, 0);
    x += d.width;
    p.place(variable, x, 0);
    x += variable.width;
    p
      ..width = x + size * 0.06
      ..ascent = [gTop, body.ascent, upper.height + gTop * 0.6].reduce(math.max)
      ..descent = math.max(gBottom, body.descent);
    return p;
  }

  _Piece _deriv(_Piece body, double size) {
    final d = _frac(_text('d', size * 0.9), _text('dx', size * 0.9), size);
    final p = _Piece(d.width + size * 0.1 + body.width, 0, 0)
      ..place(d, 0, 0)
      ..place(body, d.width + size * 0.1, 0);
    p
      ..ascent = math.max(d.ascent, body.ascent)
      ..descent = math.max(d.descent, body.descent);
    return p;
  }
}

/// A typeset expression; shows the caret at [cursor] when given, and
/// reports taps as the nearest caret position.
class GxMathView extends StatelessWidget {
  const GxMathView({
    super.key,
    required this.row,
    this.cursor,
    this.size = 20,
    required this.color,
    this.caretColor,
    this.blink,
    this.onCaret,
  });

  final GxRow row;
  final GxCursor? cursor;
  final double size;
  final Color color;
  final Color? caretColor;

  /// Caret visibility (blinking), when focused.
  final ValueNotifier<bool>? blink;
  final ValueChanged<GxCursor>? onCaret;

  @override
  Widget build(BuildContext context) {
    final t = GxTypeset(row, size: size, color: color);
    final paint = CustomPaint(
      size: Size(math.max(t.extent.width + 4, size), t.extent.height),
      painter: _MathPainter(
        t,
        cursor,
        caretColor ?? Theme.of(context).colorScheme.primary,
        blink,
      ),
    );
    if (onCaret == null) return paint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => onCaret!(t.nearest(d.localPosition)),
      child: paint,
    );
  }
}

class _MathPainter extends CustomPainter {
  _MathPainter(this.t, this.cursor, this.caretColor, this.blink)
    : super(repaint: blink);

  final GxTypeset t;
  final GxCursor? cursor;
  final Color caretColor;
  final ValueNotifier<bool>? blink;

  @override
  void paint(Canvas canvas, Size size) {
    t.paint(canvas, Offset.zero);
    final c = cursor;
    if (c == null || blink?.value == false) return;
    final r = t.caret(c);
    if (r != null) canvas.drawRect(r, Paint()..color = caretColor);
  }

  @override
  bool shouldRepaint(_MathPainter old) => true;
}
