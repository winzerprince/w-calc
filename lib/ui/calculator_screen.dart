import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/app_settings.dart';
import '../app/calc_model.dart';
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
  Calculator _calc = Calculator();
  CalcModel? _model;
  final FocusNode _focus = FocusNode(debugLabel: 'calculator');

  @override
  void initState() {
    super.initState();
    // Restore into whichever engine is current when loading finishes (the
    // model may have changed meanwhile).
    StateStore.read().then((state) {
      if (!mounted) return;
      setState(() {
        if (state != null) {
          try {
            _calc.restoreState(state);
          } on Object {
            // Corrupt or outdated snapshot: start fresh.
          }
        }
        _replayFromUrl();
      });
    });
  }

  /// Switching model keeps memories, data and setup: the state moves to a
  /// new engine with that model's features.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = ModelScope.of(context);
    if (_model == null) {
      _model = model;
      _calc = Calculator(features: model.features);
    } else if (model != _model) {
      final saved = _calc.saveState();
      _model = model;
      _calc = Calculator(features: model.features)..restoreState(saved);
      _busy = false;
      StateStore.save(_calc);
    }
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

  /// A long computation (∫dx, d/dx, SOLVE) is running.
  bool _busy = false;

  Future<void> _press(CalcKey key) async {
    if (_busy) return;
    final settings = SettingsScope.maybeOf(context);
    if (settings?.vibration ?? true) keyVibration();
    if (settings?.keySound ?? false) SystemSound.play(SystemSoundType.click);
    if (_calc.isSlowKey(key)) {
      // Like the device: clear the display while calculating. Paint that
      // frame before the (synchronous) computation starts.
      setState(() => _busy = true);
      await WidgetsBinding.instance.endOfFrame;
      _calc.press(key);
      if (mounted) setState(() => _busy = false);
    } else {
      setState(() => _calc.press(key));
    }
    StateStore.save(_calc);
  }

  /// Portrait body: phones fill the width; tablets get a larger body that
  /// keeps a calculator's proportions (keys neither stretched nor squat).
  static BoxConstraints _portraitBody(BoxConstraints box) {
    final width = [
      box.maxWidth,
      box.maxHeight / 1.75,
      620.0,
    ].reduce((a, b) => a < b ? a : b);
    return BoxConstraints(maxWidth: width, maxHeight: width * 2.25);
  }

  /// Long press on the LCD copies the shown result.
  void _copyResult() {
    final text = _busy ? null : _calc.display.copyText;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (text == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Nothing to copy'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    keyVibration();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Copied $text'),
        duration: const Duration(seconds: 2),
      ),
    );
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
    keys.forEach(_press);
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
          child: LayoutBuilder(
            builder: (context, box) {
              // Landscape: LCD beside the keypad instead of a squashed keypad.
              final landscape = box.maxWidth > box.maxHeight * 1.15;
              final lcd = _Bezel(
                child: GestureDetector(
                  key: const Key('lcd-copy'),
                  onLongPress: _copyResult,
                  child: Semantics(
                    onLongPressHint: 'copy result',
                    child: Lcd(
                      display: _busy ? DisplayState.busy : _calc.display,
                    ),
                  ),
                ),
              );
              final keypad = Keypad(onPress: _press);
              return Center(
                child: ConstrainedBox(
                  constraints: landscape
                      ? const BoxConstraints(maxWidth: 980)
                      : _portraitBody(box),
                  child: Container(
                    key: const Key('calc-body'),
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
                    child: landscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _Header(onReset: _reset),
                                    const SizedBox(height: 8),
                                    lcd,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: keypad),
                            ],
                          )
                        : Column(
                            children: [
                              _Header(onReset: _reset),
                              const SizedBox(height: 8),
                              lcd,
                              const SizedBox(height: 12),
                              Expanded(child: keypad),
                            ],
                          ),
                  ),
                ),
              );
            },
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
                  ModelScope.of(context).name.toUpperCase(),
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
