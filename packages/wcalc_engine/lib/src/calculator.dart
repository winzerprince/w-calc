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

/// A menu or prompt screen (MODE setup pages, DRG▶, Fix/Sci/Norm prompts).
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

/// Key-driven calculator state machine (COMP mode so far).
class Calculator {
  Calculator({math.Random? random}) : _random = random ?? math.Random();

  /// Maximum input steps per expression.
  static const int maxSteps = 79;

  /// From this step on the cursor turns into a block.
  static const int lowMemoryStep = 73;

  final math.Random _random;

  List<Tok> _tokens = [];
  int _cursor = 0; // token index
  int _windowStart = 0; // first visible column
  bool _insert = false;
  _Modifier _modifier = _Modifier.none;
  bool _hyp = false;
  _Phase _phase = _Phase.editing;
  _Menu? _menu;

  Dec _ans = Dec.zero;
  Dec? _resultValue;
  CalcError? _error;
  DisplayFormat _format = const DisplayFormat.norm1();
  AngleUnit _angle = AngleUnit.deg;

  AngleUnit get angleUnit => _angle;
  DisplayFormat get displayFormat => _format;

  FormattedNumber get _result => _resultValue == null
      ? const FormattedNumber('0.')
      : formatNumber(_resultValue!, _format);

  DisplayState get display {
    final indicators = {
      if (_modifier == _Modifier.shift) Indicator.shift,
      if (_modifier == _Modifier.alpha) Indicator.alpha,
      if (_hyp) Indicator.hyp,
      if (_format.mode == DisplayMode.fix) Indicator.fix,
      if (_format.mode == DisplayMode.sci) Indicator.sci,
      _angle.indicator,
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
        upper: _clip(text, 0),
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

  void press(CalcKey key) {
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
        return;
      case (_Modifier.shift, CalcKey.ans):
        _menu = _drgMenu;
        return;
      case (_Modifier.shift, CalcKey.del):
        if (_phase == _Phase.editing) _insert = !_insert;
        return;
      case (_Modifier.none, CalcKey.equals):
        _execute();
        return;
      case (_Modifier.none, CalcKey.left || CalcKey.right):
        if (_phase == _Phase.result) {
          _phase = _Phase.editing;
          _setCursor(key == CalcKey.left ? _tokens.length : 0);
        } else {
          _setCursor(_cursor + (key == CalcKey.left ? -1 : 1));
        }
        return;
      case (_Modifier.none, CalcKey.del):
        if (_phase == _Phase.editing) _delete();
        return;
      default:
        final tok = _tokenFor(key, modifier, hyp);
        if (tok != null) _enter(tok);
    }
  }

  /// Token for [key] under [modifier]/[hyp], or null if the key does nothing yet.
  static Tok? _tokenFor(CalcKey key, _Modifier modifier, bool hyp) {
    final shift = modifier == _Modifier.shift;
    if (modifier == _Modifier.alpha) {
      return switch (key) {
        CalcKey.ln => Tok.e,
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
      _clearInput();
      if (tok.kind == TokKind.binary || tok.kind == TokKind.postfix) {
        _tokens.add(Tok.ans);
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
    final d = key.digit;
    if (d == null) return;

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

  void _input(Tok tok) {
    _phase = _Phase.editing;
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

  void _execute() {
    if (_tokens.isEmpty) return;
    _insert = false;
    try {
      final value = evaluate(
        _tokens,
        ans: _ans,
        context: EvalContext(
          ans: _ans,
          angle: _angle,
          format: _format,
          random: _random,
        ),
      );
      _ans = value;
      _resultValue = value;
      _phase = _Phase.result;
    } on CalcError catch (e) {
      _error = e;
      _phase = _Phase.error;
    }
  }

  void _clearInput() {
    _tokens = [];
    _cursor = 0;
    _windowStart = 0;
    _insert = false;
    _error = null;
    _phase = _Phase.editing;
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
}
