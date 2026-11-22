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

/// Key-driven calculator state machine (COMP mode arithmetic so far).
class Calculator {
  /// Maximum input steps per expression.
  static const int maxSteps = 79;

  /// From this step on the cursor turns into a block.
  static const int lowMemoryStep = 73;

  List<Tok> _tokens = [];
  int _cursor = 0; // token index
  int _windowStart = 0; // first visible column
  bool _insert = false;
  _Modifier _modifier = _Modifier.none;
  _Phase _phase = _Phase.editing;

  Dec _ans = Dec.zero;
  FormattedNumber _result = const FormattedNumber('0.');
  CalcError? _error;
  final DisplayFormat _format = const DisplayFormat.norm1();
  final AngleUnit _angle = AngleUnit.deg;

  DisplayState get display {
    final indicators = {
      if (_modifier == _Modifier.shift) Indicator.shift,
      if (_modifier == _Modifier.alpha) Indicator.alpha,
      _angle.indicator,
    };
    if (_phase == _Phase.error) {
      return DisplayState(
        upper: _error!.kind.message,
        lower: '',
        indicators: indicators,
      );
    }
    final text = _tokens.map((t) => t.text).join();
    if (_phase == _Phase.result) {
      return DisplayState(
        upper: _clip(text, 0),
        lower: _result.mantissa,
        exponent: _result.exponent,
        indicators: indicators,
      );
    }
    return DisplayState(
      upper: _clip(text, _windowStart),
      lower: _result.mantissa,
      exponent: _result.exponent,
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
    final modifier = _modifier;
    if (key == CalcKey.shift || key == CalcKey.alpha) {
      final pressed = key == CalcKey.shift ? _Modifier.shift : _Modifier.alpha;
      _modifier = modifier == pressed ? _Modifier.none : pressed;
      return;
    }
    _modifier = _Modifier.none;

    switch (modifier) {
      case _Modifier.shift:
        if (key == CalcKey.del && _phase == _Phase.editing) _insert = !_insert;
        return; // Other SHIFT functions arrive in later milestones.
      case _Modifier.alpha:
        return;
      case _Modifier.none:
        _pressPlain(key);
    }
  }

  void _pressPlain(CalcKey key) {
    if (key == CalcKey.ac) {
      _clearInput();
      _result = const FormattedNumber('0.');
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

    switch (key) {
      case CalcKey.equals:
        _execute();
        return;
      case CalcKey.left:
      case CalcKey.right:
        if (_phase == _Phase.result) {
          _phase = _Phase.editing;
          _setCursor(key == CalcKey.left ? _tokens.length : 0);
        } else {
          _setCursor(_cursor + (key == CalcKey.left ? -1 : 1));
        }
        return;
      case CalcKey.del:
        if (_phase == _Phase.editing) _delete();
        return;
      default:
        final tok = _tokenFor(key);
        if (tok == null) return;
        if (_phase == _Phase.result) {
          _clearInput();
          if (tok.kind == TokKind.binary) _tokens.add(Tok.ans);
          _cursor = _tokens.length;
        }
        _input(tok);
    }
  }

  static Tok? _tokenFor(CalcKey key) {
    final digit = key.digit;
    if (digit != null) return Tok.digits[digit];
    return switch (key) {
      CalcKey.dot => Tok.point,
      CalcKey.exp => Tok.exp,
      CalcKey.add => Tok.add,
      CalcKey.subtract => Tok.subtract,
      CalcKey.multiply => Tok.multiply,
      CalcKey.divide => Tok.divide,
      CalcKey.negative => Tok.negative,
      CalcKey.openParen => Tok.openParen,
      CalcKey.closeParen => Tok.closeParen,
      CalcKey.ans => Tok.ans,
      _ => null,
    };
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
      final value = evaluate(_tokens, ans: _ans);
      _ans = value;
      _result = formatNumber(value, _format);
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
