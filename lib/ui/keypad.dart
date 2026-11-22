import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'keypad_layout.dart';
import 'legend.dart';

/// Full keypad: top block (modifiers + cursor disc), function rows, number rows.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onPress});

  final ValueChanged<CalcKey> onPress;

  Widget _row(List<KeySpec> specs) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final s in specs)
        Expanded(
          child: KeyButton(spec: s, onPress: onPress),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 20,
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
        for (final r in functionRows) Expanded(flex: 10, child: _row(r)),
        const SizedBox(height: 6),
        for (final r in numberRows) Expanded(flex: 13, child: _row(r)),
      ],
    );
  }
}

/// One key: secondary legends above, key cap below. Acts on pointer down like a real key.
class KeyButton extends StatefulWidget {
  const KeyButton({super.key, required this.spec, required this.onPress});

  final KeySpec spec;
  final ValueChanged<CalcKey> onPress;

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
    final shiftLabels = spec.above.where((l) => l.kind == LabelKind.shift);
    final otherLabels = spec.above.where((l) => l.kind != LabelKind.shift);
    final cap = Color.lerp(base, Colors.black, _down ? 0.25 : 0)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 13,
            child: Row(
              children: [
                Expanded(child: _labels(shiftLabels, Alignment.centerLeft)),
                Expanded(child: _labels(otherLabels, Alignment.centerRight)),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Semantics(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _labels(Iterable<KeyLabel> labels, Alignment alignment) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            for (final (i, l) in labels.indexed)
              ...legendSpans(
                i == 0 ? l.text : ' ${l.text}',
                TextStyle(
                  color: WCalcColors.label(l.kind),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Round four-way cursor disc ("REPLAY").
class CursorDisc extends StatelessWidget {
  const CursorDisc({super.key, required this.onPress});

  final ValueChanged<CalcKey> onPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.25,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE9E6DE), WCalcColors.modifierKey],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                _arrow(CalcKey.up, Icons.arrow_drop_up, Alignment.topCenter),
                _arrow(
                  CalcKey.down,
                  Icons.arrow_drop_down,
                  Alignment.bottomCenter,
                ),
                _arrow(CalcKey.left, Icons.arrow_left, Alignment.centerLeft),
                _arrow(CalcKey.right, Icons.arrow_right, Alignment.centerRight),
                const Center(
                  child: Text(
                    'REPLAY',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
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

  Widget _arrow(CalcKey key, IconData icon, Alignment alignment) => Align(
    alignment: alignment,
    child: FractionallySizedBox(
      widthFactor: alignment.x == 0 ? 0.5 : 0.33,
      heightFactor: alignment.y == 0 ? 0.5 : 0.36,
      child: Listener(
        key: Key('key-${key.name}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onPress(key),
        child: FittedBox(
          child: Icon(icon, color: Colors.black54, semanticLabel: key.name),
        ),
      ),
    ),
  );
}
