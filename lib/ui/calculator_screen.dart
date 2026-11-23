import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import '../app/app_settings.dart';
import '../app/calc_model.dart';
import '../app/history_store.dart';
import 'app_menu.dart';
import 'finish.dart';
import 'fullscreen.dart';
import 'graph/graph_page.dart';
import 'haptics.dart';
import 'pages/history_page.dart';
import 'keyboard_shortcuts.dart';
import 'keypad.dart';
import 'keypad_layout.dart' show LabelKind;
import 'lcd.dart';
import 'lcd/dot_lcd.dart';
import 'skin.dart';
import 'tour/tours.dart';
import 'state_store.dart';
import 'soft_route.dart';

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

  /// Records a calculation the engine just finished in [HistoryStore].
  void _recordHistory(List<({String input, String result})> before) {
    final after = _calc.historyEntries;
    if (after.isEmpty) return;
    final grew = after.length > before.length;
    final shifted =
        after.length == before.length &&
        before.isNotEmpty &&
        after.last != before.last;
    if (grew || shifted) {
      HistoryStore.instance.add(
        _model!.id,
        after.last.input,
        after.last.result,
      );
    }
  }

  Future<void> _press(CalcKey key) async {
    if (_busy) return;
    final historyBefore = _calc.historyEntries;
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
    _recordHistory(historyBefore);
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

  VoidCallback? _historyAction() =>
      _calc.historyEntries.isEmpty ? null : _openHistory;

  /// The History page for the model in use.
  void _openHistory() {
    keyVibration();
    Navigator.of(
      context,
    ).push(SoftRoute<void>(builder: (_) => HistoryPage(modelId: _model?.id)));
  }

  VoidCallback? _graphAction() {
    if (_calc.graphSpec == null) return null;
    return _openGraph;
  }

  void _openGraph() {
    keyVibration();
    Navigator.of(context).push(
      SoftRoute<void>(
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
                                        onHistory: _historyAction(),
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
                                  onHistory: _historyAction(),
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
    this.onHistory,
  });

  /// Shown when there are earlier calculations to look back at.
  final VoidCallback? onHistory;

  final VoidCallback onReset;
  final bool focus;
  final VoidCallback onFocus;

  /// Shown when the calculation can be graphed.
  final VoidCallback? onGraph;

  @override
  Widget build(BuildContext context) {
    final skin = CalcSkin.of(context);
    // Fixed height and fixed slots: nothing moves when contextual
    // commands appear or disappear.
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // W-Calc above the menu icon, top left.
          Align(
            alignment: Alignment.topLeft,
            child: KeyedSubtree(
              key: TourKeys.menu,
              child: _MenuButton(onReset: onReset),
            ),
          ),
          const SizedBox(width: 6),
          Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ContextSlot(
                  buttonKey: const Key('history-button'),
                  icon: Icons.history,
                  tooltip: 'Earlier calculations',
                  color: skin.brandText,
                  onTap: onHistory,
                ),
                const SizedBox(width: 4),
                _ContextSlot(
                  buttonKey: const Key('graph-button'),
                  icon: Icons.show_chart,
                  tooltip: 'Graph this',
                  color: skin.label(LabelKind.shift),
                  onTap: onGraph,
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topRight,
                child: SizedBox(
                  height: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                              padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
                              child: _solar(context),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ModelScope.of(context).name.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: skin.brandText.withValues(alpha: 0.6),
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _solar(BuildContext context) {
    final skin = CalcSkin.of(context);
    return Container(
      width: 84,
      height: 20,
      decoration: BoxDecoration(
        color: skin.solarStrip,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black54),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(1.5),
                color: Color.lerp(skin.solarStrip, Colors.white, 0.08),
              ),
            ),
        ],
      ),
    );
  }
}

/// A contextual command in a fixed slot: always takes its space, fades and
/// scales in when available, ignores taps when not.
class _ContextSlot extends StatelessWidget {
  const _ContextSlot({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return SizedBox.square(
      dimension: 32,
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: on ? 1 : 0.6,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: IgnorePointer(
            ignoring: !on,
            child: on
                ? IconButton(
                    key: buttonKey,
                    tooltip: tooltip,
                    padding: EdgeInsets.zero,
                    iconSize: 22,
                    onPressed: onTap,
                    icon: Icon(icon, color: color),
                  )
                : Icon(icon, color: color, size: 22),
          ),
        ),
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
              padding: const EdgeInsets.fromLTRB(2, 0, 8, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'W-Calc',
                    style: TextStyle(
                      color: brand,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(
                    Icons.menu,
                    color: brand.withValues(alpha: 0.8),
                    size: 22,
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
