import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/app_settings.dart';
import 'app_menu.dart';
import 'haptics.dart';
import 'keyboard_shortcuts.dart';
import 'keypad.dart';
import 'lcd.dart';
import 'skin.dart';
import 'state_store.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final Calculator _calc = Calculator();
  final FocusNode _focus = FocusNode(debugLabel: 'calculator');

  @override
  void initState() {
    super.initState();
    StateStore.load(_calc).then((_) {
      if (!mounted) return;
      setState(_replayFromUrl);
    });
  }

  /// Web: `?keys=2,div,3,=` presses those keys on load (repro links, screenshots).
  /// Comma-separated; use `plus minus times div neg` for symbols that URLs mangle.
  void _replayFromUrl() {
    final sequence = Uri.base.queryParameters['keys'];
    if (sequence == null) return;
    try {
      parseKeySequence(sequence.replaceAll(',', ' ')).forEach(_calc.press);
    } on FormatException {
      // Ignore malformed links.
    }
  }

  void _press(CalcKey key) {
    final settings = SettingsScope.maybeOf(context);
    if (settings?.vibration ?? true) keyVibration();
    if (settings?.keySound ?? false) SystemSound.play(SystemSoundType.click);
    setState(() => _calc.press(key));
    StateStore.save(_calc);
  }

  /// Settings ▸ Reset calculator.
  void _reset() {
    setState(_calc.resetAll);
    StateStore.save(_calc);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = keysForKeyboard(event);
    if (keys == null) return KeyEventResult.ignored;
    setState(() => keys.forEach(_calc.press));
    StateStore.save(_calc);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    return Scaffold(
      backgroundColor: skin.background,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [skin.bodyTop, skin.body],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _Header(onReset: _reset),
                    const SizedBox(height: 8),
                    _Bezel(child: Lcd(display: _calc.display)),
                    const SizedBox(height: 12),
                    Expanded(child: Keypad(onPress: _press)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MenuButton(onReset: onReset),
                const SizedBox(width: 8),
                Text(
                  'TWO-LINE SCIENTIFIC',
                  style: TextStyle(
                    color: CalcSkin.of(context).brandText
                        .withValues(alpha: 0.55),
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Decorative solar strip.
        Container(
          width: 92,
          height: 22,
          decoration: BoxDecoration(
            color: CalcSkin.of(context).solarStrip,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black54),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    color: Color.lerp(
                      CalcSkin.of(context).solarStrip,
                      Colors.white,
                      0.08,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bezel extends StatelessWidget {
  const _Bezel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CalcSkin.of(context).bezel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black45, width: 1.5),
      ),
      child: child,
    );
  }
}

/// The brand name doubles as the menu button: menu icon + ripple + tooltip
/// make it clearly tappable.
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final brand = CalcSkin.of(context).brandText;
    return Tooltip(
      message: 'Menu',
      child: Semantics(
        button: true,
        label: 'Open W-Calc menu',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('app-menu-button'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => showAppMenu(context, onReset: onReset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu,
                    color: brand.withValues(alpha: 0.75),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'W-Calc',
                    style: TextStyle(
                      color: brand,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
