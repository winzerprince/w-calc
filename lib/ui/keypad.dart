import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'keypad_layout.dart';
import 'legend.dart';

/// Height of one printed legend strip.
const double _stripHeight = 13;

/// Full keypad: top block (modifiers + cursor disc), function rows, number rows.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onPress});

  final ValueChanged<CalcKey> onPress;

  Widget _row(List<KeySpec> specs) {
    final hasBelow = specs.any((s) => s.below.isNotEmpty);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in specs)
          Expanded(
            child: KeyButton(spec: s, onPress: onPress, reserveBelow: hasBelow),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 21,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(child: _row(row0Left)),
                    Expanded(child: _row(row1Left)),
                  ],
                ),
              ),
              Expanded(flex: 2, child: CursorDisc(onPress: onPress)),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(child: _row(row0Right)),
                    Expanded(child: _row(row1Right)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 10, child: _row(functionRows[0])),
        Expanded(flex: 10, child: _row(functionRows[1])),
        Expanded(flex: 12, child: _row(functionRows[2])),
        const SizedBox(height: 4),
        for (final r in numberRows) Expanded(flex: 13, child: _row(r)),
      ],
    );
  }
}

/// One key: legends above (and optionally below), key cap in between.
/// Acts on pointer down like a real key.
class KeyButton extends StatefulWidget {
  const KeyButton({
    super.key,
    required this.spec,
    required this.onPress,
    this.reserveBelow = false,
  });

  final KeySpec spec;
  final ValueChanged<CalcKey> onPress;

  /// Keep space for a below-strip so caps in one row stay aligned.
  final bool reserveBelow;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final (base, fg) = switch (spec.style) {
      KeyStyle.modifier => (WCalcColors.modifierKey, const Color(0xFF22252C)),
      KeyStyle.function => (WCalcColors.functionKey, Colors.white),
      KeyStyle.digit => (WCalcColors.digitKey, Colors.white),
      KeyStyle.operator => (WCalcColors.operatorKey, Colors.white),
      KeyStyle.clear => (WCalcColors.clearKey, Colors.white),
    };
    final cap = Color.lerp(base, Colors.black, _down ? 0.25 : 0)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _stripHeight,
            child: LegendStrip(labels: spec.above, below: false),
          ),
          const SizedBox(height: 1),
          Expanded(child: _cap(spec, cap, fg)),
          if (widget.reserveBelow)
            SizedBox(
              height: _stripHeight,
              child: LegendStrip(labels: spec.below, below: true),
            ),
        ],
      ),
    );
  }

  Widget _cap(KeySpec spec, Color cap, Color fg) {
    return Semantics(
      button: true,
      label: legendText(spec.main),
      child: Listener(
        key: Key('key-${spec.key.name}'),
        onPointerDown: (_) {
          setState(() => _down = true);
          widget.onPress(spec.key);
        },
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, _down ? 1.5 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              spec.style == KeyStyle.modifier ? 20 : 9,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(cap, Colors.white, 0.10)!, cap],
            ),
            boxShadow: _down
                ? const []
                : const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text.rich(
                TextSpan(
                  children: legendSpans(
                    spec.main,
                    TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: switch (spec.style) {
                        KeyStyle.digit => 24,
                        KeyStyle.operator => 26,
                        KeyStyle.modifier => 13,
                        _ => 16,
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legends printed next to a key: left / center / right slots, so each legend
/// sits clearly over its own key in the device's left-to-right order.
class LegendStrip extends StatelessWidget {
  const LegendStrip({super.key, required this.labels, required this.below});

  final List<KeyLabel> labels;
  final bool below;

  Widget _slot(LabelSlot slot) {
    final items = labels.where((l) => l.slot == slot).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, l) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 3),
          LegendText(label: l, below: below),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    // Each slot keeps its natural size, pinned to the key's left edge,
    // centre or right edge (like the printed legends). If the legends are
    // wider than the key, the whole strip scales down uniformly.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: _MinWidth(
            width: width,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slot(LabelSlot.left),
                const _Gap(),
                _slot(LabelSlot.center),
                const _Gap(),
                _slot(LabelSlot.right),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Expands to fill the remaining width between slots.
class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 4);
}

/// Lays out [child] at its intrinsic width but at least [width], spreading
/// the slots: left at the start, center in the middle, right at the end.
class _MinWidth extends StatelessWidget {
  const _MinWidth({required this.width, required this.child});

  final double width;
  final Row child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: child.children,
        ),
      ),
    );
  }
}

/// One legend; mode-specific ones get corner brackets in the mode colour.
class LegendText extends StatelessWidget {
  const LegendText({super.key, required this.label, required this.below});

  final KeyLabel label;
  final bool below;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(
        children: legendSpans(
          label.text,
          TextStyle(
            color: WCalcColors.label(label.kind),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
    final bracket = label.bracket;
    if (bracket == null) return text;
    return CustomPaint(
      painter: _BracketPainter(WCalcColors.label(bracket), openDown: !below),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: text,
      ),
    );
  }
}

/// Corner brackets: ┌ ┐ above keys (open downward), └ ┘ below keys.
class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color, {required this.openDown});

  final Color color;
  final bool openDown;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final y = openDown ? 0.5 : size.height - 0.5;
    final tip = openDown ? size.height * 0.55 : size.height * 0.45;
    for (final x in [0.5, size.width - 0.5]) {
      final inward = x < 1 ? 3.0 : -3.0;
      canvas.drawPath(
        Path()
          ..moveTo(x + inward, y)
          ..lineTo(x, y)
          ..lineTo(x, tip),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color || old.openDown != openDown;
}

/// Oval four-way cursor disc ("REPLAY") with printed triangles.
class CursorDisc extends StatelessWidget {
  const CursorDisc({super.key, required this.onPress});

  final ValueChanged<CalcKey> onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.3,
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              shape: OvalBorder(),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFECE9E2), WCalcColors.modifierKey],
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                _zone(CalcKey.up, Alignment.topCenter, AxisDirection.up),
                _zone(CalcKey.down, Alignment.bottomCenter, AxisDirection.down),
                _zone(CalcKey.left, Alignment.centerLeft, AxisDirection.left),
                _zone(
                  CalcKey.right,
                  Alignment.centerRight,
                  AxisDirection.right,
                ),
                const Center(
                  child: IgnorePointer(
                    child: Text(
                      'REPLAY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A877F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _zone(CalcKey key, Alignment alignment, AxisDirection dir) {
    final vertical = dir == AxisDirection.up || dir == AxisDirection.down;
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: vertical ? 0.5 : 0.3,
        heightFactor: vertical ? 0.36 : 0.5,
        child: Semantics(
          button: true,
          label: 'cursor ${dir.name}',
          child: Listener(
            key: Key('key-${key.name}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onPress(key),
            child: CustomPaint(painter: _TrianglePainter(dir)),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.dir);

  final AxisDirection dir;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * 0.22;
    final c = size.center(Offset.zero);
    final path = switch (dir) {
      AxisDirection.up =>
        Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy + s * 0.6)
          ..lineTo(c.dx - s, c.dy + s * 0.6),
      AxisDirection.down =>
        Path()
          ..moveTo(c.dx, c.dy + s)
          ..lineTo(c.dx + s, c.dy - s * 0.6)
          ..lineTo(c.dx - s, c.dy - s * 0.6),
      AxisDirection.left =>
        Path()
          ..moveTo(c.dx - s, c.dy)
          ..lineTo(c.dx + s * 0.6, c.dy - s)
          ..lineTo(c.dx + s * 0.6, c.dy + s),
      AxisDirection.right =>
        Path()
          ..moveTo(c.dx + s, c.dy)
          ..lineTo(c.dx - s * 0.6, c.dy - s)
          ..lineTo(c.dx - s * 0.6, c.dy + s),
    };
    canvas.drawPath(path..close(), Paint()..color = const Color(0xFF8A877F));
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.dir != dir;
}
