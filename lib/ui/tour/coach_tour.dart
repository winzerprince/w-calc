import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One note of a tour: what to point at and what to say about it.
class TourStep {
  const TourStep(this.target, this.text);

  /// Widget to highlight; null points nowhere (a closing note).
  final GlobalKey? target;
  final String text;
}

/// Shows [steps] as whiteboard-style notes over a dark scrim. Any tap moves
/// on; "skip" (or the last tap) ends the tour.
Future<void> showTour(BuildContext context, List<TourStep> steps) {
  if (steps.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _TourOverlay(steps: steps),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
        child: child,
      ),
    ),
  );
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps});

  final List<TourStep> steps;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  int _index = 0;

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= widget.steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    await _draw.reverse(from: 0.35);
    if (!mounted) return;
    setState(() => _index++);
    _draw.forward(from: 0);
  }

  Rect? _targetRect(TourStep step) {
    final ctx = step.target?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final overlay = context.findRenderObject() as RenderBox?;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final rect = _targetRect(step);
    final size = MediaQuery.sizeOf(context);
    final textBelow = rect == null || rect.center.dy < size.height * 0.45;
    const handStyle = TextStyle(
      fontFamily: 'Hand',
      color: Colors.white,
      fontSize: 27,
      height: 1.15,
      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
    );
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        label:
            'Tour ${_index + 1} of ${widget.steps.length}: ${step.text}. '
            'Tap to continue.',
        child: GestureDetector(
          key: const Key('tour-overlay'),
          behavior: HitTestBehavior.opaque,
          onTap: _next,
          child: AnimatedBuilder(
            animation: _draw,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_draw.value);
              final textBox = _textBox(size, rect, textBelow);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TourPainter(
                        target: rect,
                        progress: t,
                        from: textBelow
                            ? textBox.topCenter + const Offset(0, -6)
                            : textBox.bottomCenter + const Offset(0, 6),
                        seed: _index,
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: textBox,
                    child: Opacity(
                      opacity: t,
                      child: Transform.rotate(
                        angle: (_index.isEven ? -1 : 1) * 0.025,
                        child: Transform.scale(
                          scale: 0.92 + 0.08 * t,
                          child: Center(
                            child: Text(
                              step.text,
                              key: const Key('tour-text'),
                              textAlign: TextAlign.center,
                              style: handStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: MediaQuery.paddingOf(context).top + 8,
                    child: TextButton(
                      key: const Key('tour-skip'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'skip',
                        style: handStyle.copyWith(fontSize: 21),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 14,
                    child: Text(
                      '${_index + 1} / ${widget.steps.length}   ·   tap to continue',
                      textAlign: TextAlign.center,
                      style: handStyle.copyWith(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Where the note goes: above or below the highlighted area.
  Rect _textBox(Size size, Rect? target, bool below) {
    const margin = 28.0, h = 150.0;
    if (target == null) {
      return Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width - 2 * margin,
        height: h,
      );
    }
    final top = below
        ? math.min(target.bottom + 70, size.height - h - 60)
        : math.max(target.top - 70 - h, 60.0);
    return Rect.fromLTWH(margin, top, size.width - 2 * margin, h);
  }
}

/// Scrim with a spotlight, a hand-drawn ring around the target and a
/// marker arrow from the note to it, drawn progressively.
class _TourPainter extends CustomPainter {
  _TourPainter({
    required this.target,
    required this.progress,
    required this.from,
    required this.seed,
  });

  final Rect? target;
  final double progress;
  final Offset from;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.74);
    final t = target;
    if (t == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final hole = RRect.fromRectAndRadius(
      t.inflate(8),
      const Radius.circular(14),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(hole),
      ),
      scrim,
    );

    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Ring: a wobbly loop that overshoots its start, like a marker circle.
    final rnd = math.Random(seed * 7 + 3);
    final ring = Path();
    final c = t.center;
    final rx = t.width / 2 + 14, ry = t.height / 2 + 12;
    const steps = 48;
    for (var i = 0; i <= steps + 6; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / steps;
      final wobble = 1 + (rnd.nextDouble() - 0.5) * 0.06;
      final p =
          c + Offset(math.cos(a) * rx * wobble, math.sin(a) * ry * wobble);
      if (i == 0) {
        ring.moveTo(p.dx, p.dy);
      } else {
        ring.lineTo(p.dx, p.dy);
      }
    }
    _drawPartial(canvas, ring, pen, (progress * 1.6).clamp(0, 1));

    // Arrow: a gentle curve from the note to the ring's edge.
    final toward = c - from;
    final dist = toward.distance;
    if (dist < 1) return;
    final dir = toward / dist;
    final end = c - Offset(dir.dx * rx * 1.02, dir.dy * ry * 1.02);
    final normal = Offset(-dir.dy, dir.dx);
    final bend = (seed.isEven ? 1 : -1) * dist * 0.22;
    final ctrl = Offset.lerp(from, end, 0.5)! + normal * bend;
    final arrow = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    final arrowT = ((progress - 0.25) / 0.6).clamp(0.0, 1.0);
    _drawPartial(canvas, arrow, pen, arrowT);
    if (arrowT >= 1) {
      // Arrow head: two short strokes back from the tip.
      final back = (end - ctrl);
      final b = back / back.distance;
      final n = Offset(-b.dy, b.dx);
      final head = Path()
        ..moveTo(end.dx - b.dx * 16 + n.dx * 9, end.dy - b.dy * 16 + n.dy * 9)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx - b.dx * 16 - n.dx * 9, end.dy - b.dy * 16 - n.dy * 9);
      canvas.drawPath(head, pen);
    }
  }

  void _drawPartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final ui.PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_TourPainter old) =>
      old.progress != progress || old.target != target || old.from != from;
}
