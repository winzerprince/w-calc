import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/app_settings.dart';
import '../app/calc_model.dart';
import 'app_menu.dart';
import 'finish.dart';
import 'fullscreen.dart';
import 'graph/graph_page.dart';
import 'haptics.dart';
import 'keyboard_shortcuts.dart';
import 'keypad.dart';
import 'keypad_layout.dart' show LabelKind;
import 'lcd.dart';
import 'lcd/dot_lcd.dart';
import 'skin.dart';
import 'tour/tours.dart';
import 'state_store.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  CalcEngine _calc = Calculator();
  CalcModel? _model;

  String get _stateKey => _model?.family == CalcFamily.textbook
      ? StateStore.textbookKey
      : StateStore.twoLineKey;
  final FocusNode _focus = FocusNode(debugLabel: 'calculator');

  /// Switching model keeps memories, data and setup: the state moves to a
  /// new engine with that model's features.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = ModelScope.of(context);
    if (_model == null) {
      _model = model;
      _calc = model.createEngine();
      _load(_calc, replayUrl: true);
    } else if (model != _model) {
      final old = _model!;
      StateStore.save(_calc, _stateKey);
      _busy = false;
      if (old.family == model.family) {
        final saved = _calc.saveState();
        _model = model;
        _calc = model.createEngine()..restoreState(saved);
        StateStore.save(_calc, _stateKey);
      } else {
        // Another engine family: its own memories and setup.
        _model = model;
        _calc = model.createEngine();
        _load(_calc);
      }
    }
  }

  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    calculatorTourRequest.addListener(replayTour);
  }

  /// First run: the calculator tour, once preferences are known.
  void _maybeTour() {
    final settings = SettingsScope.maybeOf(context);
    if (_tourChecked || settings == null || !settings.loaded) return;
    _tourChecked = true;
    runTourOnce(context, Tours.calculator, () => calculatorTour(_model!));
  }

  /// Settings ▸ Tours ▸ Calculator.
  void replayTour() => runTourOnce(
    context,
    Tours.calculator,
    () => calculatorTour(_model!),
    force: true,
  );

  /// Restores [engine]'s saved state once storage answers, if it is still
  /// the engine in use.
  void _load(CalcEngine engine, {bool replayUrl = false}) {
    StateStore.read(_stateKey).then((state) {
      if (!mounted || !identical(_calc, engine)) return;
      setState(() {
        if (state != null) {
          try {
            engine.restoreState(state);
          } on Object {
            // Corrupt or outdated snapshot: start fresh.
          }
        }
        if (replayUrl) _replayFromUrl();
      });
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
    StateStore.save(_calc, _stateKey);
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
    final text = _busy ? null : _calc.copyText;
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

  /// Focus mode: system bars hidden, calculator edge to edge.
  bool _focusMode = false;

  void _toggleFocus() {
    keyVibration();
    setState(() => _focusMode = !_focusMode);
    setFullscreen(_focusMode);
  }

  VoidCallback? _graphAction() {
    if (_calc.graphSpec == null) return null;
    return _openGraph;
  }

  void _openGraph() {
    keyVibration();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GraphPage(spec: _calc.graphSpec, angle: _calc.angleUnit),
      ),
    );
  }

  /// Settings ▸ Reset calculator.
  void _reset() {
    setState(_calc.resetAll);
    StateStore.save(_calc, _stateKey);
  }

  Widget _lcd() {
    final calc = _calc;
    if (calc is NaturalCalculator) {
      return DotLcd(
        screen: _busy
            ? DotScreen(dots: DotBitmap(DotScreen.width, DotScreen.height))
            : calc.screen,
      );
    }
    return Lcd(
      display: _busy ? DisplayState.busy : (calc as Calculator).display,
    );
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
    calculatorTourRequest.removeListener(replayTour);
    if (_focusMode) setFullscreen(false);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybeTour();
    final skin = CalcSkin.of(context);
    return Scaffold(
      backgroundColor: skin.background,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          top: !_focusMode,
          bottom: !_focusMode,
          child: LayoutBuilder(
            builder: (context, box) {
              // Landscape: LCD beside the keypad instead of a squashed keypad.
              final landscape = box.maxWidth > box.maxHeight * 1.15;
              final lcd = _Bezel(
                key: TourKeys.lcd,
                child: GestureDetector(
                  key: const Key('lcd-copy'),
                  onLongPress: _copyResult,
                  child: Semantics(
                    onLongPressHint: 'copy result',
                    child: _lcd(),
                  ),
                ),
              );
              final keypad = KeyedSubtree(
                key: TourKeys.keypad,
                child: Keypad(onPress: _press, tourTargets: true),
              );
              return Center(
                child: ConstrainedBox(
                  constraints: landscape
                      ? const BoxConstraints(maxWidth: 980)
                      : _portraitBody(box),
                  child: Container(
                    key: const Key('calc-body'),
                    margin: EdgeInsets.all(_focusMode ? 0 : 8),
                    child: CalcShell(
                      flat: _focusMode,
                      child: landscape
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Header(
                                        onReset: _reset,
                                        focus: _focusMode,
                                        onFocus: _toggleFocus,
                                        onGraph: _graphAction(),
                                      ),
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
                                _Header(
                                  onReset: _reset,
                                  focus: _focusMode,
                                  onFocus: _toggleFocus,
                                  onGraph: _graphAction(),
                                ),
                                const SizedBox(height: 8),
                                lcd,
                                const SizedBox(height: 12),
                                Expanded(child: keypad),
                              ],
                            ),
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
  const _Header({
    required this.onReset,
    required this.focus,
    required this.onFocus,
    this.onGraph,
  });

  final VoidCallback onReset;
  final bool focus;
  final VoidCallback onFocus;

  /// Shown when the calculation can be graphed (it uses X).
  final VoidCallback? onGraph;

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
                KeyedSubtree(
                  key: TourKeys.menu,
                  child: _MenuButton(onReset: onReset),
                ),
                // Contextual command: graph the expression in X.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: onGraph == null
                      ? const SizedBox(key: ValueKey('no-graph'), width: 0)
                      : IconButton(
                          key: const Key('graph-button'),
                          tooltip: 'Graph this',
                          visualDensity: VisualDensity.compact,
                          onPressed: onGraph,
                          icon: Icon(
                            Icons.show_chart,
                            color: CalcSkin.of(context).label(LabelKind.shift),
                          ),
                        ),
                ),
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
        // The solar panel toggles focus (full-screen) mode.
        Tooltip(
          message: focus ? 'Exit full screen' : 'Full screen',
          child: Semantics(
            button: true,
            toggled: focus,
            label: 'Full screen',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('solar-panel'),
              behavior: HitTestBehavior.opaque,
              onTap: onFocus,
              child: Padding(
                key: TourKeys.solar,
                padding: const EdgeInsets.all(4),
                child: _solar(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _solar(BuildContext context) {
    return Container(
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
    );
  }
}

class _Bezel extends StatelessWidget {
  const _Bezel({super.key, required this.child});

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
