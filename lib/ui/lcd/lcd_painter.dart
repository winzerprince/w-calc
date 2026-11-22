import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'dot_font.dart';
import 'seven_segment.dart';

/// Colours of the LCD glass.
class LcdPalette {
  const LcdPalette({required this.glass, required this.ink});

  final Color glass;
  final Color ink;

  static const classic = LcdPalette(
    glass: Color(0xFFC3CDB2),
    ink: Color(0xFF1C2117),
  );
}

/// Paints the whole two-line LCD in a fixed design space of
/// [designWidth] × [designHeight], scaled to the widget size.
class LcdPainter extends CustomPainter {
  LcdPainter({
    required this.display,
    required this.cursorVisible,
    this.palette = LcdPalette.classic,
  });

  final DisplayState display;
  final bool cursorVisible;
  final LcdPalette palette;

  static const double designWidth = 1000;
  static const double designHeight = 380;
  static const double aspectRatio = designWidth / designHeight;

  static const double _pad = 26;

  // Upper line: 12 cells × 6 dot columns.
  static const double _dotPitch = 12.9;
  static const double _dotSize = 10.6;
  static const double _upperTop = 62;

  // Result line.
  static const double _lowerTop = 192;
  static const double _digitW = 70;
  static const double _digitH = 140;
  static const double _expW = 34;
  static const double _expH = 66;
  static const int _mantissaCells = 11; // sign + 10 digits
  static const double _mantissaRight = designWidth - _pad - 130;

  /// Indicator slots, left to right (fixed positions like printed LCD segments).
  static const indicatorSlots = <(Indicator, String)>[
    (Indicator.shift, 'S'),
    (Indicator.alpha, 'A'),
    (Indicator.hyp, 'hyp'),
    (Indicator.memory, 'M'),
    (Indicator.sto, 'STO'),
    (Indicator.rcl, 'RCL'),
    (Indicator.sd, 'SD'),
    (Indicator.reg, 'REG'),
    (Indicator.fix, 'FIX'),
    (Indicator.sci, 'SCI'),
    (Indicator.eng, 'ENG'),
    (Indicator.deg, 'D'),
    (Indicator.rad, 'R'),
    (Indicator.gra, 'G'),
    (Indicator.cmplx, 'CMPLX'),
    (Indicator.mat, 'MAT'),
    (Indicator.vct, 'VCT'),
    (Indicator.reIm, 'R⇔I'),
    (Indicator.scrollUp, '▲'),
    (Indicator.scrollDown, '▼'),
    (Indicator.disp, 'Disp'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / designWidth, size.height / designHeight);
    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      const Radius.circular(18),
    );
    canvas.drawRRect(glass, Paint()..color = palette.glass);
    // Subtle inner shading for a glass feel.
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, designHeight),
          [
            Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.06),
          ],
          [0, 0.25, 1],
        ),
    );
    _paintIndicators(canvas);
    _paintUpper(canvas);
    _paintLower(canvas);
    canvas.restore();
  }

  Paint get _inkPaint => Paint()..color = palette.ink;

  void _paintIndicators(Canvas canvas) {
    const style = TextStyle(
      fontFamily: 'Barlow',
      fontFamilyFallback: ['WCalcSymbols'],
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1,
    );
    final painters = [
      for (final (_, label) in indicatorSlots)
        TextPainter(
          text: TextSpan(
            text: label,
            style: style.copyWith(color: palette.ink),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final total = painters.fold<double>(0, (s, p) => s + p.width);
    final gap = (designWidth - 2 * _pad - total) / (painters.length - 1);
    var x = _pad;
    for (var i = 0; i < painters.length; i++) {
      if (display.indicators.contains(indicatorSlots[i].$1)) {
        painters[i].paint(canvas, Offset(x, 12));
      }
      x += painters[i].width + gap;
    }
  }

  void _paintUpper(Canvas canvas) {
    final text = display.upper;
    final ink = _inkPaint;
    for (var col = 0; col < DisplayState.upperColumns; col++) {
      final x0 = _pad + col * 6 * _dotPitch;
      final ch = col < text.length ? text[col] : ' ';
      final isCursor = display.cursor == col && cursorVisible;
      var glyph = glyphFor(ch);
      if (isCursor && display.cursorStyle == CursorStyle.block) {
        glyph = glyphFor('■');
      }
      for (var r = 0; r < dotFontHeight; r++) {
        for (var c = 0; c < dotFontWidth; c++) {
          if (glyph[r][c] == '#') _dot(canvas, x0, r, c, ink);
        }
      }
      if (!isCursor) continue;
      switch (display.cursorStyle) {
        case CursorStyle.underscore:
          for (var c = 0; c < dotFontWidth; c++) {
            _dot(canvas, x0, dotFontHeight + 0.6, c, ink);
          }
        case CursorStyle.insert:
          final rect = Rect.fromLTWH(
            x0 - 2.5,
            _upperTop - 2.5,
            dotFontWidth * _dotPitch + 3,
            dotFontHeight * _dotPitch + 3,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = palette.ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        case CursorStyle.block:
          break;
      }
    }
  }

  void _dot(Canvas canvas, double x0, num row, int col, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x0 + col * _dotPitch,
          _upperTop + row * _dotPitch,
          _dotSize,
          _dotSize,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  void _paintLower(Canvas canvas) {
    final ghost = Paint()..color = palette.ink.withValues(alpha: 0.05);
    final ink = _inkPaint;
    // Ghost segments for every digit position (unlit LCD look).
    for (var i = 0; i < _mantissaCells; i++) {
      final x = _mantissaRight - (_mantissaCells - i) * _digitW;
      _segments(
        canvas,
        Offset(x, _lowerTop),
        _digitW,
        _digitH,
        Segment.values.toSet(),
        const SegmentCell('8', point: true, comma: true),
        ghost,
      );
    }
    for (var i = 0; i < 3; i++) {
      _segments(
        canvas,
        Offset(_mantissaRight + 24 + i * _expW, _lowerTop),
        _expW,
        _expH,
        i == 0 ? {Segment.g} : Segment.values.toSet(),
        null,
        ghost,
      );
    }

    final grouped = display.exponent == null
        ? groupDigits(display.lower)
        : display.lower;
    final cells = toCells(grouped);
    final start = _mantissaCells - cells.length;
    for (var i = 0; i < cells.length; i++) {
      final x = _mantissaRight - (_mantissaCells - (start + i)) * _digitW;
      _segments(
        canvas,
        Offset(x, _lowerTop),
        _digitW,
        _digitH,
        segmentsFor(cells[i].char),
        cells[i],
        ink,
      );
    }

    final exp = display.exponent;
    if (exp != null) {
      final digits = exp.startsWith('-') ? exp.substring(1) : exp;
      if (exp.startsWith('-')) {
        _segments(
          canvas,
          Offset(_mantissaRight + 24, _lowerTop),
          _expW,
          _expH,
          {Segment.g},
          null,
          ink,
        );
      }
      for (var i = 0; i < digits.length && i < 2; i++) {
        _segments(
          canvas,
          Offset(_mantissaRight + 24 + (i + 1) * _expW, _lowerTop),
          _expW,
          _expH,
          segmentsFor(digits[i]),
          null,
          ink,
        );
      }
    }
  }

  /// Draws a slanted seven-segment digit in the box [origin] [w]×[h].
  void _segments(
    Canvas canvas,
    Offset origin,
    double w,
    double h,
    Set<Segment> on,
    SegmentCell? marks,
    Paint paint,
  ) {
    final t = w * 0.15; // stroke
    final m = w * 0.12; // side margin
    final iw = w - 2 * m;
    const slant = 0.10;
    Offset p(double x, double y) => origin + Offset(m + x + (h - y) * slant, y);
    Path bar(Offset a, Offset b, bool horizontal) {
      final half = t / 2;
      final path = Path();
      if (horizontal) {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx + half, a.dy - half)
          ..lineTo(b.dx - half, b.dy - half)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx - half, b.dy + half)
          ..lineTo(a.dx + half, a.dy + half);
      } else {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(a.dx + half, a.dy + half)
          ..lineTo(b.dx + half, b.dy - half)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx - half, b.dy - half)
          ..lineTo(a.dx - half, a.dy + half);
      }
      return path..close();
    }

    final gap = t * 0.25;
    final top = t / 2, mid = h / 2, bot = h - t / 2;
    final l = t / 2, r = iw - t / 2;
    final defs = <Segment, Path>{
      Segment.a: bar(p(l + gap, top), p(r - gap, top), true),
      Segment.g: bar(p(l + gap, mid), p(r - gap, mid), true),
      Segment.d: bar(p(l + gap, bot), p(r - gap, bot), true),
      Segment.f: bar(p(l, top + gap), p(l, mid - gap), false),
      Segment.b: bar(p(r, top + gap), p(r, mid - gap), false),
      Segment.e: bar(p(l, mid + gap), p(l, bot - gap), false),
      Segment.c: bar(p(r, mid + gap), p(r, bot - gap), false),
    };
    for (final s in on) {
      canvas.drawPath(defs[s]!, paint);
    }
    if (marks == null) return;
    // Every digit position has a dot and a comma tail after it.
    final dot = origin + Offset(w - m * 0.2, h - t / 2);
    if (marks.point || marks.comma) {
      canvas.drawCircle(dot, t * 0.6, paint);
    }
    if (marks.comma) {
      canvas.drawPath(
        Path()
          ..moveTo(dot.dx + t * 0.15, dot.dy + t * 0.3)
          ..lineTo(dot.dx + t * 0.55, dot.dy + t * 0.3)
          ..lineTo(dot.dx - t * 0.45, dot.dy + t * 1.9)
          ..lineTo(dot.dx - t * 0.75, dot.dy + t * 1.9)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LcdPainter old) =>
      old.display != display ||
      old.cursorVisible != cursorVisible ||
      old.palette != palette;
}
