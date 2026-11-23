import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../../app/calc_model.dart';
import '../skin.dart';
import 'lcd_painter.dart';

/// Full-dot LCD of the textbook-display models: an indicator row over the
/// 96 × 31 dot area. The engine draws the dots; this only paints them and
/// blinks the cursor.
class DotLcd extends StatefulWidget {
  const DotLcd({super.key, required this.screen});

  final DotScreen screen;

  /// Indicator row + dot area, in dots.
  static const double aspectRatio = 96 / (31 + 7 + 4);

  @override
  State<DotLcd> createState() => _DotLcdState();
}

class _DotLcdState extends State<DotLcd> {
  Timer? _blink;
  bool _cursorOn = true;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(DotLcd old) {
    super.didUpdateWidget(old);
    _restart();
  }

  void _restart() {
    _blink?.cancel();
    _cursorOn = true;
    if (widget.screen.cursor == null) return;
    _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.screen;
    final labels = ModelScope.of(context).indicatorLabels;
    return Semantics(
      key: const Key('lcd'),
      label: s.text,
      liveRegion: true,
      child: Stack(
        children: [
          Offstage(
            child: Column(
              children: [
                Text(s.text, key: const Key('lcd-text')),
                Text(
                  s.indicators.map((i) => i.name).join(' '),
                  key: const Key('lcd-indicators'),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: DotLcd.aspectRatio,
            child: glowingLcd(
              CalcSkin.of(context).lcd,
              CustomPaint(
                painter: _DotLcdPainter(
                  labels: labels,
                  screen: s,
                  cursorOn: _cursorOn,
                  palette: CalcSkin.of(context).lcd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicator labels in their fixed order along the top of the glass.
const _indicatorOrder = [
  (Indicator.shift, 'S'),
  (Indicator.alpha, 'A'),
  (Indicator.memory, 'M'),
  (Indicator.sto, 'STO'),
  (Indicator.rcl, 'RCL'),
  (Indicator.stat, 'STAT'),
  (Indicator.cmplx, 'CMPLX'),
  (Indicator.mat, 'MAT'),
  (Indicator.vct, 'VCT'),
  (Indicator.deg, 'D'),
  (Indicator.rad, 'R'),
  (Indicator.gra, 'G'),
  (Indicator.fix, 'FIX'),
  (Indicator.sci, 'SCI'),
  (Indicator.math, 'Math'),
  (Indicator.scrollUp, '▲'),
  (Indicator.scrollDown, '▼'),
  (Indicator.disp, 'Disp'),
];

class _DotLcdPainter extends CustomPainter {
  _DotLcdPainter({
    required this.labels,
    required this.screen,
    required this.cursorOn,
    required this.palette,
  });

  final Map<Indicator, String> labels;
  final DotScreen screen;
  final bool cursorOn;
  final LcdPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glass = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height * 0.04),
    );
    canvas.drawRRect(glass, Paint()..color = palette.glass);
    if (screen.isOff) {
      paintGlassOverlay(canvas, glass);
      return;
    }
    final ink = palette.ink.withValues(
      alpha: (1.0 + screen.contrast * 0.11).clamp(0.4, 1.0),
    );

    // Dot grid: 96 columns with a margin; 31 rows under the indicator row.
    final cell = size.width / (DotScreen.width + 4);
    final left = cell * 2;
    final indicatorH = cell * 7;
    final top = indicatorH + cell * 2;

    // Indicators (always the same slots, only lit ones drawn).
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final slotW = (size.width - 2 * left) / _indicatorOrder.length;
    for (var i = 0; i < _indicatorOrder.length; i++) {
      final (ind, standard) = _indicatorOrder[i];
      final label = labels[ind] ?? standard;
      if (!screen.indicators.contains(ind)) continue;
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: ink,
          fontFamily: 'Barlow',
          fontFamilyFallback: const ['WCalcSymbols'],
          fontSize: indicatorH * 0.78,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
      tp.layout();
      final x = left + slotW * i + (slotW - tp.width) / 2;
      tp.paint(canvas, Offset(x, cell * 1.2));
    }

    // Faint ghost of the dot grid, then the lit dots.
    final dot = cell * 0.86;
    final lit = Paint()..color = ink;
    final ghost = Paint()
      ..color = palette.ink.withValues(
        alpha: 0.035 + (screen.contrast > 0 ? screen.contrast * 0.008 : 0),
      );
    // Two batched draws (lit dots, ghost dots) instead of ~3000 rects.
    final bmp = screen.dots;
    final on = <Offset>[], off = <Offset>[];
    final half = dot / 2;
    for (var y = 0; y < DotScreen.height; y++) {
      for (var x = 0; x < DotScreen.width; x++) {
        final p = Offset(left + x * cell + half, top + y * cell + half);
        (bmp.get(x, y) ? on : off).add(p);
      }
    }
    final square = Paint()
      ..strokeWidth = dot
      ..strokeCap = StrokeCap.square;
    canvas.drawPoints(ui.PointMode.points, off, square..color = ghost.color);
    canvas.drawPoints(ui.PointMode.points, on, square..color = lit.color);

    // Blinking vertical bar cursor.
    final c = screen.cursor;
    if (c != null && cursorOn) {
      canvas.drawRect(
        Rect.fromLTWH(
          left + c.x * cell,
          top + c.top * cell,
          dot,
          c.height * cell - (cell - dot),
        ),
        lit,
      );
    }
    paintGlassOverlay(canvas, glass);
  }

  @override
  bool shouldRepaint(_DotLcdPainter old) =>
      old.screen != screen ||
      old.cursorOn != cursorOn ||
      old.palette != palette;
}
