import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/links.dart';
import 'haptics.dart';

/// Quiet "Buy me a coffee" line for the menu: a small cup with steam
/// drifting up. Opens Ko-fi.
class CoffeeLink extends StatefulWidget {
  const CoffeeLink({super.key});

  @override
  State<CoffeeLink> createState() => _CoffeeLinkState();
}

class _CoffeeLinkState extends State<CoffeeLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _steam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _steam.stop();
    } else if (!_steam.isAnimating) {
      _steam.repeat();
    }
  }

  @override
  void dispose() {
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buy me a coffee on Ko-fi',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('menu-kofi'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          keyVibration();
          openLink(kofiUrl);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _steam,
                builder: (context, _) => CustomPaint(
                  size: const Size(26, 28),
                  painter: _CupPainter(_steam.value),
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Enjoying W-Calc? Buy me a coffee',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    // Cup and handle.
    final top = h * 0.55;
    final cup = Path()
      ..moveTo(w * 0.1, top)
      ..lineTo(w * 0.72, top)
      ..lineTo(w * 0.66, h * 0.95)
      ..lineTo(w * 0.16, h * 0.95)
      ..close();
    canvas.drawPath(cup, line);
    canvas.drawArc(
      Rect.fromLTWH(w * 0.6, top + h * 0.06, w * 0.3, h * 0.22),
      -math.pi / 2,
      math.pi,
      false,
      line,
    );
    // Three wisps of steam rising and fading, out of step.
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1.0;
      final x = w * (0.22 + 0.17 * k);
      final y0 = top - 2 - p * h * 0.42;
      final fade = math.sin(p * math.pi);
      final wisp = Path()..moveTo(x, y0);
      for (var s = 1; s <= 6; s++) {
        final f = s / 6;
        wisp.lineTo(
          x + math.sin((f + p) * 2 * math.pi) * 2.2,
          y0 - f * h * 0.22,
        );
      }
      canvas.drawPath(
        wisp,
        line..color = Colors.white.withValues(alpha: 0.55 * fade),
      );
      line.color = Colors.white70;
    }
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.t != t;
}
