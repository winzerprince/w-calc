import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'skin.dart';

/// Hue of the Neon Rainbow theme, 0–1, drifting while that theme is on.
class NeonHue extends InheritedNotifier<ValueNotifier<double>> {
  const NeonHue({super.key, required super.notifier, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NeonHue>()?.notifier?.value ??
      0;
}

/// Drives [NeonHue] with one slow ticker, only for rainbow skins.
class NeonClock extends StatefulWidget {
  const NeonClock({super.key, required this.child});

  final Widget child;

  @override
  State<NeonClock> createState() => _NeonClockState();
}

class _NeonClockState extends State<NeonClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..addListener(() => _hue.value = _c.value);
  final _hue = ValueNotifier<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = CalcSkin.of(context).rainbow;
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    _hue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NeonHue(notifier: _hue, child: widget.child);
}

/// The glow colour now (rainbow: drifting hue; [offset] shifts it so keys
/// across the keypad show a gentle spread of colours).
Color neonColor(BuildContext context, {double offset = 0}) {
  final skin = CalcSkin.of(context);
  if (skin.neon != null) return skin.neon!;
  final h = ((NeonHue.of(context) + offset) % 1.0) * 360;
  return HSVColor.fromAHSV(1, h, 0.75, 1).toColor();
}

/// A bright segment travelling once round a rounded rectangle, with a
/// soft glow, like light running along a neon tube.
class NeonSnakePainter extends CustomPainter {
  NeonSnakePainter({
    required this.progress,
    required this.color,
    required this.radius,
    this.length = 0.28,
    this.width = 2.4,
  });

  /// 0 → 1 over one lap (nothing drawn at 0 or 1).
  final double progress;
  final Color color;
  final double radius;
  final double length;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(radius),
    );
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    final total = metric.length;
    final head = total * progress;
    final tail = head - total * length;
    // Fade in and out at the ends of the lap.
    final fade = math.sin(progress * math.pi);
    final seg = Path();
    if (tail >= 0) {
      seg.addPath(metric.extractPath(tail, head), Offset.zero);
    } else {
      seg
        ..addPath(metric.extractPath(total + tail, total), Offset.zero)
        ..addPath(metric.extractPath(0, head), Offset.zero);
    }
    final glow = Paint()
      ..color = color.withValues(alpha: 0.55 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 3.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    final core = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(seg, glow)
      ..drawPath(seg, core);
  }

  @override
  bool shouldRepaint(NeonSnakePainter old) =>
      old.progress != progress || old.color != color;
}
