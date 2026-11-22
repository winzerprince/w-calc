import 'dart:math' as math;

import 'angle_unit.dart';
import 'calc_key.dart';
import 'display_state.dart';
import 'eval/evaluator.dart';
import 'format/number_format.dart';
import 'input/token.dart';
import 'number/dec.dart';

enum _Modifier { none, shift, alpha }

enum _Phase {
  /// Typing or editing an expression.
  editing,

  /// A result is shown; the next key decides between new input, Ans-chaining or replay.
  result,

  /// An error message is shown.
  error,
}

/// Waiting for a variable key after STO or RCL.
enum _Pending { none, sto, rcl }

/// A menu or prompt screen (MODE pages, CLR, DRG▶, Fix/Sci/Norm prompts).
class _Menu {
  const _Menu(this.text, this.marks);

  final String text;
  final Map<int, String> marks;
}

const _modePages = [
  _Menu('COMP CMPLX', {1: '1', 7: '2'}),
  _Menu('SD REG BASE', {1: '1', 4: '2', 8: '3'}),
  _Menu('EQN MAT VCT', {1: '1', 5: '2', 9: '3'}),
  _Menu('Deg Rad Gra', {1: '1', 5: '2', 9: '3'}),
  _Menu('Fix Sci Norm', {1: '1', 5: '2', 9: '3'}),
  _Menu('Disp', {1: '1'}),
];
const _drgMenu = _Menu(' D   R   G', {1: '1', 5: '2', 9: '3'});
const _fixPrompt = _Menu('Fix 0~9?', {});
const _sciPrompt = _Menu('Sci 0~9?', {});
const _normPrompt = _Menu('Norm 1~2?', {});
const _clrMenu = _Menu('Mcl Mode All', {1: '1', 5: '2', 10: '3'});

/// CLR confirmations (press = to execute, AC to cancel).
const _clrMcl = _Menu('Mcl', {});
const _clrMode = _Menu('Mode', {});
const _clrAll = _Menu('All', {});

/// One calculation-history entry: what was typed and what it gave.
class _Entry {
  _Entry(this.tokens, this.value);

  final List<Tok> tokens;
  final Dec value;

  /// Approximate memory use, for the ~150-byte history budget.
  int get bytes => tokens.length + 7;
}

/// Variable names in key order, with the key that selects each after STO/RCL.
const _variableKeys = {
  CalcKey.negative: Tok.varA,
  CalcKey.degMinSec: Tok.varB,
  CalcKey.hyp: Tok.varC,
  CalcKey.sin: Tok.varD,
  CalcKey.cos: Tok.varE,
  CalcKey.tan: Tok.varF,
  CalcKey.mPlus: Tok.varM,
  CalcKey.closeParen: Tok.varX,
  CalcKey.comma: Tok.varY,
};

/// Key-driven calculator state machine (COMP mode so far).
class Calculator {
  Calculator({math.Random? random}) : _random = random ?? math.Random();

  /// Maximum input steps per expression.
  static const int maxSteps = 79;

  /// From this step on the cursor turns into a block.
  static const int lowMemoryStep = 73;

  /// Calculation history budget (manual: "approximately 150 bytes").
  static const int historyBytes = 150;

  final math.Random _random;

  List<Tok> _tokens = [];
  int _cursor = 0; // token index
  int _windowStart = 0; // first visible column
  bool _insert = false;
  _Modifier _modifier = _Modifier.none;
  bool _hyp = false;
  _Pending _pending = _Pending.none;
  _Phase _phase = _Phase.editing;
  _Menu? _menu;

  Dec _ans = Dec.zero;
  Dec? _resultValue;
  CalcError? _error;
  DisplayFormat _format = const DisplayFormat.norm1();
  AngleUnit _angle = AngleUnit.deg;
  final Map<String, Dec> _vars = {};

  /// Upper-line text while a result is shown, when it differs from the input
  /// (current statement of a multi-statement, `A=` after RCL).
  String? _upperOverride;

  /// Token an operator continues from after a result (Ans, or the recalled variable).
  Tok _continueWith = Tok.ans;

  final List<_Entry> _history = [];
  int? _browse; // history index shown in the result phase

  /// Multi-statement execution: statement ranges and the one shown.
  List<(int, int)> _statements = const [];
  int _statement = 0;

  AngleUnit get angleUnit => _angle;
  DisplayFormat get displayFormat => _format;

  bool get _midMulti =>
      _phase == _Phase.result && _statement < _statements.length - 1;

  FormattedNumber get _result => _resultValue == null
      ? const FormattedNumber('0.')
      : formatNumber(_resultValue!, _format);

  DisplayState get display {
    final browse = _browse;
    final showScroll = _phase == _Phase.result && browse != null && !_midMulti;
    final indicators = {
      if (_modifier == _Modifier.shift) Indicator.shift,
      if (_modifier == _Modifier.alpha) Indicator.alpha,
      if (_hyp) Indicator.hyp,
      if (_pending == _Pending.sto) Indicator.sto,
      if (_pending == _Pending.rcl) Indicator.rcl,
      if (!(_vars['M'] ?? Dec.zero).isZero) Indicator.memory,
      if (_format.mode == DisplayMode.fix) Indicator.fix,
      if (_format.mode == DisplayMode.sci) Indicator.sci,
      _angle.indicator,
      if (showScroll && browse > 0) Indicator.scrollUp,
      if (showScroll && browse < _history.length - 1) Indicator.scrollDown,
      if (_midMulti) Indicator.disp,
    };
    final menu = _menu;
    if (menu != null) {
      return DisplayState(
        upper: menu.text,
        lower: '',
        indicators: indicators,
        menuMarks: menu.marks,
      );
    }
    if (_phase == _Phase.error) {
      return DisplayState(
        upper: _error!.kind.message,
        lower: '',
        indicators: indicators,
      );
    }
    final text = _tokens.map((t) => t.text).join();
    final result = _result;
    if (_phase == _Phase.result) {
      return DisplayState(
        upper: _clip(_upperOverride ?? text, 0),
        lower: result.mantissa,
        exponent: result.exponent,
        indicators: indicators,
      );
    }
    return DisplayState(
      upper: _clip(text, _windowStart),
      lower: result.mantissa,
      exponent: result.exponent,
      indicators: indicators,
      cursor: _cursorColumn - _windowStart,
      cursorStyle: _insert
          ? CursorStyle.insert
          : (_tokens.length >= lowMemoryStep
                ? CursorStyle.block
                : CursorStyle.underscore),
    );
  }

  // ------------------------------------------------------------------ keys

  void press(CalcKey key) {
    if (key == CalcKey.on) {
      _powerOn();
      return;
    }
    if (_menu != null) {
      _pressInMenu(key);
      return;
    }
    final modifier = _modifier;
    if (key == CalcKey.shift || key == CalcKey.alpha) {
      final pressed = key == CalcKey.shift ? _Modifier.shift : _Modifier.alpha;
      _modifier = modifier == pressed ? _Modifier.none : pressed;
      return;
    }
    if (_pending != _Pending.none) {
      _pressPending(key);
      return;
    }
    if (key == CalcKey.hyp && modifier == _Modifier.none) {
      _hyp = !_hyp;
      return;
    }
    _modifier = _Modifier.none;
    final hyp = _hyp;
    _hyp = false;

    if (key == CalcKey.ac) {
      _clearInput();
      _resultValue = null;
      return;
    }
    if (_phase == _Phase.error) {
      if (key == CalcKey.left || key == CalcKey.right) {
        _phase = _Phase.editing;
        _setCursor(_error!.position ?? _tokens.length);
        _error = null;
      }
      return;
    }

    switch ((modifier, key)) {
      case (_Modifier.none, CalcKey.mode):
        _menu = _modePages.first;
      case (_Modifier.shift, CalcKey.mode):
        _menu = _clrMenu;
      case (_Modifier.shift, CalcKey.ans):
        _menu = _drgMenu;
      case (_Modifier.shift, CalcKey.rcl):
        _pending = _Pending.sto;
      case (_Modifier.none, CalcKey.rcl):
        _pending = _Pending.rcl;
      case (_Modifier.none, CalcKey.mPlus):
        _addToMemory(1);
      case (_Modifier.shift, CalcKey.mPlus):
        _addToMemory(-1);
      case (_Modifier.shift, CalcKey.del):
        if (_phase == _Phase.editing) _insert = !_insert;
      case (_Modifier.none, CalcKey.equals):
        _execute();
      case (_Modifier.none, CalcKey.up || CalcKey.down):
        _scrollHistory(key == CalcKey.up ? -1 : 1);
      case (_Modifier.shift, CalcKey.up):
        _copyHistory();
      case (_Modifier.none, CalcKey.left || CalcKey.right):
        if (_phase == _Phase.result) {
          _startEditing(key == CalcKey.left ? _tokens.length : 0);
        } else {
          _setCursor(_cursor + (key == CalcKey.left ? -1 : 1));
        }
      case (_Modifier.none, CalcKey.del):
        if (_phase == _Phase.editing) _delete();
      default:
        final tok = _tokenFor(key, modifier, hyp);
        if (tok != null) _enter(tok);
    }
  }

  /// Token for [key] under [modifier]/[hyp], or null if the key does nothing yet.
  static Tok? _tokenFor(CalcKey key, _Modifier modifier, bool hyp) {
    final shift = modifier == _Modifier.shift;
    if (modifier == _Modifier.alpha) {
      return _variableKeys[key] ??
          switch (key) {
            CalcKey.ln => Tok.e,
            CalcKey.integrate => Tok.colon,
            _ => null,
          };
    }
    final digit = key.digit;
    if (digit != null) {
      if (!shift) return Tok.digits[digit];
      return digit == 0 ? Tok.rnd : null;
    }
    return switch (key) {
      CalcKey.sin => _trig(Tok.sin, Tok.asin, Tok.sinh, Tok.asinh, shift, hyp),
      CalcKey.cos => _trig(Tok.cos, Tok.acos, Tok.cosh, Tok.acosh, shift, hyp),
      CalcKey.tan => _trig(Tok.tan, Tok.atan, Tok.tanh, Tok.atanh, shift, hyp),
      CalcKey.log => shift ? Tok.tenPow : Tok.log,
      CalcKey.ln => shift ? Tok.ePow : Tok.ln,
      CalcKey.sqrt => shift ? Tok.cbrt : Tok.sqrt,
      CalcKey.square => shift ? Tok.cube : Tok.square,
      CalcKey.power => shift ? Tok.xRoot : Tok.power,
      CalcKey.reciprocal => shift ? Tok.factorial : Tok.reciprocal,
      CalcKey.multiply => shift ? Tok.nPr : Tok.multiply,
      CalcKey.divide => shift ? Tok.nCr : Tok.divide,
      CalcKey.exp => shift ? Tok.pi : Tok.exp,
      CalcKey.dot => shift ? Tok.ran : Tok.point,
      _ when shift => null,
      CalcKey.add => Tok.add,
      CalcKey.subtract => Tok.subtract,
      CalcKey.negative => Tok.negative,
      CalcKey.openParen => Tok.openParen,
      CalcKey.closeParen => Tok.closeParen,
      CalcKey.ans => Tok.ans,
      _ => null,
    };
  }

  static Tok _trig(
    Tok plain,
    Tok inverse,
    Tok hyperbolic,
    Tok inverseHyp,
    bool shift,
    bool hyp,
  ) => switch ((hyp, shift)) {
    (false, false) => plain,
    (false, true) => inverse,
    (true, false) => hyperbolic,
    (true, true) => inverseHyp,
  };

  /// Inserts [tok]; right after a result, operators continue from Ans.
  void _enter(Tok tok) {
    if (_phase == _Phase.result) {
      final continueWith = _continueWith;
      _clearInput();
      if (tok.kind == TokKind.binary || tok.kind == TokKind.postfix) {
        _tokens.add(continueWith);
      }
      _cursor = _tokens.length;
      if (tok == Tok.rnd) {
        // Rnd after a result rounds Ans (manual: 10 ÷ 3 = Rnd × 3 = 9.999).
        _input(tok);
        _input(Tok.ans);
        return;
      }
    }
    _input(tok);
  }

  // ------------------------------------------------------------------ menus

  void _pressInMenu(CalcKey key) {
    final menu = _menu!;
    _modifier = _Modifier.none;
    if (key == CalcKey.ac) {
      _menu = null;
      return;
    }
    if (key == CalcKey.mode && _modePages.contains(menu)) {
      // After the last setup page, MODE returns to the calculation screen.
      final next = _modePages.indexOf(menu) + 1;
      _menu = next < _modePages.length ? _modePages[next] : null;
      return;
    }
    if (identical(menu, _clrMcl) ||
        identical(menu, _clrMode) ||
        identical(menu, _clrAll)) {
      if (key == CalcKey.equals) _clear(menu);
      return;
    }
    final d = key.digit;
    if (d == null) return;

    if (identical(menu, _clrMenu)) {
      if (d >= 1 && d <= 3) _menu = [_clrMcl, _clrMode, _clrAll][d - 1];
      return;
    }
    if (identical(menu, _drgMenu)) {
      const marks = [Tok.degMark, Tok.radMark, Tok.graMark];
      if (d < 1 || d > 3) return;
      _menu = null;
      _enter(marks[d - 1]);
      return;
    }
    if (identical(menu, _fixPrompt)) {
      _format = DisplayFormat.fix(d);
      _menu = null;
      return;
    }
    if (identical(menu, _sciPrompt)) {
      _format = DisplayFormat.sci(d);
      _menu = null;
      return;
    }
    if (identical(menu, _normPrompt)) {
      if (d != 1 && d != 2) return;
      _format = d == 1
          ? const DisplayFormat.norm1()
          : const DisplayFormat.norm2();
      _menu = null;
      return;
    }
    switch ((_modePages.indexOf(menu), d)) {
      case (0, 1): // COMP
        _menu = null;
      case (3, 1 || 2 || 3):
        _angle = AngleUnit.values[d - 1];
        _menu = null;
      case (4, 1):
        _menu = _fixPrompt;
      case (4, 2):
        _menu = _sciPrompt;
      case (4, 3):
        _menu = _normPrompt;
      default:
        // CMPLX, SD, REG, BASE, EQN, MAT, VCT, Disp: later milestones.
        break;
    }
  }

  /// Executes a confirmed CLR choice.
  void _clear(_Menu which) {
    if (!identical(which, _clrMode)) _vars.clear();
    if (!identical(which, _clrMcl)) {
      _angle = AngleUnit.deg;
      _format = const DisplayFormat.norm1();
      _history.clear();
    }
    if (identical(which, _clrAll)) _ans = Dec.zero;
    _menu = null;
    _clearInput();
    _resultValue = null;
  }

  // ------------------------------------------------------------------ memory

  void _pressPending(CalcKey key) {
    final pending = _pending;
    _pending = _Pending.none;
    _modifier = _Modifier.none;
    final variable = _variableKeys[key];
    if (variable == null) {
      if (key == CalcKey.ac) {
        _clearInput();
        _resultValue = null;
      }
      return; // Any other key cancels STO / RCL.
    }
    if (pending == _Pending.sto) {
      final value = _commitValue();
      if (value == null) return;
      _vars[variable.text] = value;
      _ans = value;
      _resultValue = value;
    } else {
      _resultValue = _vars[variable.text] ?? Dec.zero;
      _tokens = [variable];
      _cursor = _tokens.length;
      _upperOverride = '${variable.text}=';
      _continueWith = variable;
      _browse = null;
      _phase = _Phase.result;
    }
  }

  /// M+ ([sign] 1) / M− ([sign] −1): evaluate, then add to / subtract from M.
  void _addToMemory(int sign) {
    final value = _commitValue();
    if (value == null) return;
    final m = _vars['M'] ?? Dec.zero;
    try {
      _vars['M'] = sign > 0 ? m + value : m - value;
    } on CalcError catch (e) {
      _showError(e);
      return;
    }
    _ans = value;
    _resultValue = value;
  }

  /// The value STO / M+ act on: evaluates pending input (like =), otherwise
  /// the value on the display. Null if evaluation failed (error shown).
  Dec? _commitValue() {
    if (_phase == _Phase.editing && _tokens.isNotEmpty) {
      _execute();
      while (_midMulti) {
        _execute();
      }
      return _phase == _Phase.result ? _resultValue : null;
    }
    return _resultValue ?? Dec.zero;
  }

  // ------------------------------------------------------------------ execution

  void _execute() {
    if (_midMulti) {
      _runStatement(_statement + 1);
      return;
    }
    if (_tokens.isEmpty) return;
    _insert = false;
    _upperOverride = null;
    _continueWith = Tok.ans;
    // Split at ':' into statements.
    final statements = <(int, int)>[];
    var start = 0;
    for (var i = 0; i <= _tokens.length; i++) {
      if (i == _tokens.length || _tokens[i] == Tok.colon) {
        if (i == start) {
          _showError(CalcError(CalcErrorKind.syntax, i));
          return;
        }
        statements.add((start, i));
        start = i + 1;
      }
    }
    _statements = statements;
    _runStatement(0);
  }

  void _runStatement(int index) {
    final (start, end) = _statements[index];
    try {
      final value = evaluate(
        _tokens.sublist(start, end),
        ans: _ans,
        context: EvalContext(
          ans: _ans,
          angle: _angle,
          format: _format,
          variables: _vars,
          random: _random,
        ),
      );
      _ans = value;
      _resultValue = value;
      _statement = index;
      _phase = _Phase.result;
      _upperOverride = _statements.length > 1
          ? _tokens.sublist(start, end).map((t) => t.text).join()
          : null;
      if (index == _statements.length - 1) _record(value);
    } on CalcError catch (e) {
      _showError(CalcError(e.kind, start + (e.position ?? end - start)));
    }
  }

  void _showError(CalcError e) {
    _error = e;
    _phase = _Phase.error;
    _statements = const [];
    _upperOverride = null;
  }

  // ------------------------------------------------------------------ history

  void _record(Dec value) {
    _history.add(_Entry(List.of(_tokens), value));
    var bytes = _history.fold<int>(0, (s, e) => s + e.bytes);
    while (_history.length > 1 && bytes > historyBytes) {
      bytes -= _history.removeAt(0).bytes;
    }
    _browse = _history.length - 1;
  }

  void _scrollHistory(int step) {
    if (_history.isEmpty || _midMulti) return;
    int target;
    if (_phase == _Phase.result && _browse != null) {
      target = _browse! + step;
    } else if (_phase == _Phase.editing && _tokens.isEmpty) {
      target = _history.length - 1; // After AC, ▲ shows the newest entry.
    } else {
      return;
    }
    if (target < 0 || target >= _history.length) return;
    final entry = _history[target];
    _browse = target;
    _tokens = List.of(entry.tokens);
    _cursor = _tokens.length;
    _resultValue = entry.value;
    _upperOverride = null;
    _continueWith = Tok.ans;
    _statements = const [];
    _phase = _Phase.result;
  }

  /// COPY: joins the shown entry and all newer ones into one multi-statement.
  void _copyHistory() {
    final from = _browse;
    if (_phase != _Phase.result || from == null || _midMulti) return;
    final joined = <Tok>[];
    for (var i = from; i < _history.length; i++) {
      if (joined.isNotEmpty) joined.add(Tok.colon);
      joined.addAll(_history[i].tokens);
    }
    _tokens = joined.length > maxSteps ? joined.sublist(0, maxSteps) : joined;
    _startEditing(_tokens.length);
  }

  // ------------------------------------------------------------------ editing

  void _startEditing(int cursor) {
    _phase = _Phase.editing;
    _upperOverride = null;
    _statements = const [];
    _browse = null;
    _windowStart = 0;
    _setCursor(cursor);
  }

  void _input(Tok tok) {
    _phase = _Phase.editing;
    _browse = null;
    _upperOverride = null;
    _statements = const [];
    if (_cursor < _tokens.length && !_insert) {
      _tokens[_cursor] = tok;
    } else {
      if (_tokens.length >= maxSteps) return;
      _tokens.insert(_cursor, tok);
    }
    _setCursor(_cursor + 1);
  }

  void _delete() {
    if (_tokens.isEmpty) return;
    if (_insert) {
      if (_cursor == 0) return;
      _tokens.removeAt(_cursor - 1);
      _setCursor(_cursor - 1);
    } else if (_cursor >= _tokens.length) {
      _tokens.removeLast();
      _setCursor(_tokens.length);
    } else {
      _tokens.removeAt(_cursor);
      _setCursor(_cursor);
    }
  }

  void _clearInput() {
    _tokens = [];
    _cursor = 0;
    _windowStart = 0;
    _insert = false;
    _error = null;
    _phase = _Phase.editing;
    _upperOverride = null;
    _statements = const [];
    _continueWith = Tok.ans;
    _browse = null;
  }

  /// ON: clears the screen and calculation history; memories stay.
  void _powerOn() {
    _menu = null;
    _modifier = _Modifier.none;
    _hyp = false;
    _pending = _Pending.none;
    _clearInput();
    _resultValue = null;
    _history.clear();
  }

  int get _cursorColumn {
    var col = 0;
    for (var i = 0; i < _cursor; i++) {
      col += _tokens[i].text.length;
    }
    return col;
  }

  /// Moves the cursor (clamped) and scrolls the window to keep it visible.
  void _setCursor(int index) {
    _cursor = index.clamp(0, _tokens.length);
    final col = _cursorColumn;
    const width = DisplayState.upperColumns;
    if (col < _windowStart) _windowStart = col;
    if (col >= _windowStart + width) _windowStart = col - width + 1;
  }

  static String _clip(String text, int start) {
    if (start >= text.length) return '';
    final end = (start + DisplayState.upperColumns).clamp(0, text.length);
    return text.substring(start, end);
  }

  // ------------------------------------------------------------------ persistence

  /// What survives switching the device off: memories, Ans and setup.
  Map<String, Object?> saveState() => {
    'version': 1,
    'ans': _ans.toString(),
    'vars': {for (final e in _vars.entries) e.key: e.value.toString()},
    'angle': _angle.name,
    'format': '${_format.mode.name}:${_format.digits}',
  };

  /// Restores [saveState] output; silently ignores anything malformed.
  void restoreState(Map<String, Object?> state) {
    try {
      final ans = state['ans'];
      final vars = state['vars'];
      final angle = state['angle'];
      final format = state['format'];
      final newVars = <String, Dec>{};
      if (vars is Map) {
        for (final MapEntry(:key, :value) in vars.entries) {
          if (key is String && value is String) newVars[key] = Dec.parse(value);
        }
      }
      final newAns = ans is String ? Dec.parse(ans) : _ans;
      final newAngle = angle is String
          ? AngleUnit.values.byName(angle)
          : _angle;
      final newFormat = format is String ? _parseFormat(format) : _format;
      _vars
        ..clear()
        ..addAll(newVars);
      _ans = newAns;
      _angle = newAngle;
      _format = newFormat;
    } on Object {
      // Corrupt or foreign snapshot: keep defaults.
    }
  }

  static DisplayFormat _parseFormat(String s) {
    final [mode, digits] = s.split(':');
    final n = int.parse(digits);
    return switch (mode) {
      'fix' => DisplayFormat.fix(n),
      'sci' => DisplayFormat.sci(n),
      _ => n == 2 ? const DisplayFormat.norm2() : const DisplayFormat.norm1(),
    };
  }
}
