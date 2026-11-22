import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'keypad_layout.dart';
import 'lcd.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final Calculator _calc = Calculator();

  void _press(CalcKey key) {
    HapticFeedback.selectionClick();
    setState(() => _calc.press(key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WCalcColors.body,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'W-Calc',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Lcd(display: _calc.display),
                  const SizedBox(height: 12),
                  Expanded(child: _Keypad(onPress: _press)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPress});

  final ValueChanged<CalcKey> onPress;

  Widget _row(List<KeySpec> specs, {int flex = 1}) => Expanded(
    flex: flex,
    child: Row(
      children: [
        for (final s in specs)
          Expanded(
            child: _Key(spec: s, onPress: onPress),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(children: [_row(row0Left), _row(row1Left)]),
              ),
              Expanded(flex: 2, child: _CursorPad(onPress: onPress)),
              Expanded(
                flex: 2,
                child: Column(children: [_row(row0Right), _row(row1Right)]),
              ),
            ],
          ),
        ),
        for (final r in functionRows) _row(r),
        for (final r in numberRows) _row(r, flex: 1),
      ],
    );
  }
}

class _CursorPad extends StatelessWidget {
  const _CursorPad({required this.onPress});

  final ValueChanged<CalcKey> onPress;

  Widget _arrow(CalcKey key, IconData icon) => IconButton(
    key: Key('key-${key.name}'),
    onPressed: () => onPress(key),
    icon: Icon(icon, size: 18),
    color: Colors.black54,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: WCalcColors.modifierKey,
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _arrow(CalcKey.up, Icons.arrow_drop_up),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _arrow(CalcKey.down, Icons.arrow_drop_down),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _arrow(CalcKey.left, Icons.arrow_left),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _arrow(CalcKey.right, Icons.arrow_right),
            ),
            const Center(
              child: Text(
                'REPLAY',
                style: TextStyle(fontSize: 8, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.spec, required this.onPress});

  final KeySpec spec;
  final ValueChanged<CalcKey> onPress;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (spec.style) {
      KeyStyle.modifier => (WCalcColors.modifierKey, Colors.black87),
      KeyStyle.function => (WCalcColors.functionKey, Colors.white),
      KeyStyle.digit ||
      KeyStyle.operator => (WCalcColors.digitKey, Colors.white),
      KeyStyle.clear => (WCalcColors.clearKey, Colors.white),
    };
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          SizedBox(
            height: 12,
            child: FittedBox(
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final l in spec.above)
                      TextSpan(
                        text: '${l.text} ',
                        style: TextStyle(color: WCalcColors.label(l.kind)),
                      ),
                  ],
                ),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('key-${spec.key.name}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onPress(spec.key),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        spec.main,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
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
}
