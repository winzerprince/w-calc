import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/calc_model.dart';
import 'keypad_layout.dart';
import 'legend.dart';
import 'skin.dart';

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
    final skin = CalcSkin.of(context);
    final model = ModelScope.of(context);
    final (base, fg) = switch (spec.style) {
      KeyStyle.modifier => (skin.modifierKey, skin.modifierText),
      KeyStyle.function => (skin.functionKey, skin.functionText),
      KeyStyle.digit => (skin.digitKey, skin.digitText),
      KeyStyle.operator => (skin.operatorKey, skin.digitText),
      KeyStyle.clear => (skin.clearKey, skin.clearText),
    };
    final cap = Color.lerp(base, Colors.black, _down ? 0.25 : 0)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _stripHeight,
            child: LegendStrip(
              labels: [
                for (final l in spec.above)
                  if (model.showsLegend(spec.key, l)) l,
              ],
              below: false,
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Opacity(
              // Keys without a function on this model are drawn faded.
              opacity: model.keyEnabled(spec.key) ? 1 : 0.35,
              child: _cap(spec, cap, fg),
            ),
          ),
          if (widget.reserveBelow)
            SizedBox(
              height: _stripHeight,
              child: LegendStrip(
                labels: [
                  for (final l in spec.below)
                    if (model.showsLegend(spec.key, l)) l,
                ],
                below: true,
              ),
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

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    // Legends of one key form a tight group (left → centre → right order),
    // centred over the key, so a key's legends are closer to each other than
    // to the neighbouring keys' legends. Scales down if wider than the key.
    final ordered = [
      for (final slot in LabelSlot.values)
        ...labels.where((l) => l.slot == slot),
    ];
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, l) in ordered.indexed) ...[
              if (i > 0) const SizedBox(width: _legendGap),
              LegendText(label: l, below: below),
            ],
          ],
        ),
      ),
    );
  }
}

/// Space between two legends of the same key.
const double _legendGap = 5;

/// One legend; mode-specific ones get corner brackets in the mode colour.
class LegendText extends StatelessWidget {
  const LegendText({super.key, required this.label, required this.below});

  final KeyLabel label;
  final bool below;

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    final text = Text.rich(
      TextSpan(
        children: legendSpans(
          label.text,
          TextStyle(
            color: skin.label(label.kind),
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
      painter: _BracketPainter(skin.label(bracket), openDown: !below),
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
    final skin = CalcSkin.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.3,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: OvalBorder(),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(skin.disc, Colors.white, 0.12)!, skin.disc],
              ),
              shadows: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                for (final (key, align, dir) in const [
                  (CalcKey.up, Alignment.topCenter, AxisDirection.up),
                  (CalcKey.down, Alignment.bottomCenter, AxisDirection.down),
                  (CalcKey.left, Alignment.centerLeft, AxisDirection.left),
                  (CalcKey.right, Alignment.centerRight, AxisDirection.right),
                ])
                  _zone(key, align, dir, skin.discMark),
                Center(
                  child: IgnorePointer(
                    child: Text(
                      'REPLAY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: skin.discMark,
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

  Widget _zone(
    CalcKey key,
    Alignment alignment,
    AxisDirection dir,
    Color color,
  ) {
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
            child: CustomPaint(painter: _TrianglePainter(dir, color)),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.dir, this.color);

  final AxisDirection dir;
  final Color color;

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
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.dir != dir || old.color != color;
}
