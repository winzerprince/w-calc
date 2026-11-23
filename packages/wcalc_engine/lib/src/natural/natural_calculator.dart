import 'dart:math' as math;

import '../angle_unit.dart';
import '../calc_key.dart';
import '../display_state.dart';
import '../eval/evaluator.dart';
import '../format/number_format.dart';
import '../format/value_format.dart';
import '../input/token.dart';
import '../lcd/dot_bitmap.dart';
import '../number/dec.dart';
import '../number/frac.dart';
import '../number/value.dart';
import 'dot_screen.dart';
import 'math_input.dart';
import 'math_render.dart';

/// Calculation modes of the textbook-display models (MODE 1-8).
enum NaturalMode { comp, cmplx, stat, base, eqn, matrix, table, vector }

/// A menu screen: up to four text lines; digit keys pick items.
final class _Menu {
  const _Menu(this.lines, this.actions, {this.next, this.prev});

  final List<String> lines;
  final Map<int, void Function()> actions;

  /// Pages reached with ▼ / ▲ (setup menu).
  final _Menu Function()? next;
  final _Menu Function()? prev;
}

/// One entry of the calculation history (▲ ▼ after a result).
final class _History {
  _History(this.input, this.result);

  final MathRow input;
  final Value result;

  int get bytes => input.bytes + 8;
}

/// State machine of the textbook-display calculators (silver / black units).
///
/// Shares the evaluator, number types and functions with the two-line
/// models; adds the 2-D input editor, exact result forms and the menu-style
/// MODE / SETUP screens. Draws its own 96 × 31 dot screen.
class NaturalCalculator {
  NaturalCalculator({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  // ------------------------------------------------------------- setup
  NaturalMode mode = NaturalMode.comp;

  /// MthIO (true) or LineIO.
  bool mathInput = true;

  /// MthIO-MathO (true) or MthIO-LineO (results in linear form).
  bool mathOutput = true;

  AngleUnit angle = AngleUnit.deg;
  DisplayFormat format = const DisplayFormat.norm1();

  /// d/c (true, default) or ab/c.
  bool improper = true;
  bool decimalComma = false;
  bool polarComplex = false;
  bool statFrequency = false;
  int contrast = 0;

  // ------------------------------------------------------------- state
  final MathEditor _ed = MathEditor();
  bool _shift = false;
  bool _alpha = false;
  bool _sto = false;
  bool _rcl = false;
  bool _off = false;

  /// LineIO overwrite mode (SHIFT DEL).
  bool _overwrite = false;

  Value _ans = Value.zero;
  final Map<String, Value> _vars = {
    for (final n in const ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'])
      n: Value.zero,
  };

  Value? _result;
  bool _resultShown = false;

  /// S⇔D pressed: showing the alternative form.
  bool _alternate = false;

  /// SHIFT S⇔D: mixed ↔ improper for this result.
  bool _flipMixed = false;

  /// ENG: exponent chosen for engineering view.
  int? _engExponent;

  String? _error;
  MathCursor? _errorCursor;

  _Menu? _menu;

  /// Two-digit entry after CONST / CONV.
  String? _numberPrompt;
  String _numberDigits = '';
  void Function(int)? _numberDone;

  final List<_History> _history = [];
  int? _historyIndex;
  static const historyBytes = 200;

  int _scrollX = 0;

  Map<String, Value> get variables => Map.unmodifiable(_vars);
  Value get ans => _ans;

  // ------------------------------------------------------------- keys
  bool isSlowKey(CalcKey key) =>
      key == CalcKey.equals && !_shift && _menu == null && _error == null;

  void press(CalcKey key) {
    if (_off) {
      if (key == CalcKey.on) _turnOn();
      return;
    }
    if (key == CalcKey.on) {
      _turnOn();
      return;
    }
    if (_error != null) {
      _onErrorKey(key);
      return;
    }
    if (_numberPrompt != null) {
      _onNumberPrompt(key);
      return;
    }
    if (_menu != null) {
      _onMenuKey(key);
      return;
    }
    if (key == CalcKey.shift) {
      _shift = !_shift;
      _alpha = false;
      return;
    }
    if (key == CalcKey.alpha) {
      _alpha = !_alpha;
      _shift = false;
      return;
    }
    final shift = _shift, alpha = _alpha;
    _shift = _alpha = false;
    if (_sto || _rcl) {
      _onMemoryKey(key);
      return;
    }
    if (alpha) {
      _onAlpha(key);
    } else if (shift) {
      _onShift(key);
    } else {
      _onPlain(key);
    }
  }

  void _turnOn() {
    _off = false;
    _shift = _alpha = _sto = _rcl = false;
    _menu = null;
    _numberPrompt = null;
    _error = null;
    _history.clear();
    _historyIndex = null;
    _clearInput();
  }

  void _clearInput() {
    _ed.clear();
    _result = null;
    _resultShown = false;
    _alternate = false;
    _flipMixed = false;
    _engExponent = null;
    _scrollX = 0;
  }

  // ----------------------------------------------------------- input helpers

  static const _continuation = {
    TokKind.binary,
    TokKind.postfix,
    TokKind.percent,
  };

  /// After a result: operators continue from Ans, anything else starts over.
  void _beforeInput({bool continues = false}) {
    if (!_resultShown) return;
    _resultShown = false;
    _historyIndex = null;
    _ed.clear();
    _scrollX = 0;
    if (continues) _ed.insertTok(Tok.ans);
  }

  void _tok(Tok t, {bool paren = false}) {
    _beforeInput(continues: _continuation.contains(t.kind));
    if (_overwrite && !mathInput && _ed.cursor.pos < _ed.row.items.length) {
      _ed.row.items.removeAt(_ed.cursor.pos);
    }
    _ed.insertTok(t, paren: paren);
  }

  /// Function with an opening parenthesis (sin(, log(, Abs( in LineIO …).
  void _fn(Tok t) => _tok(t, paren: true);

  void _template(MathTemplate t, {Tok? linear}) {
    if (!mathInput) {
      // LineIO: the linear equivalent.
      switch (t) {
        case MathTemplate.fraction:
          _tok(Tok.fracSep);
        case MathTemplate.mixed:
          _tok(Tok.fracSep);
        case MathTemplate.power:
          _tok(Tok.power);
          _ed.insertTok(Tok.openParen);
        case MathTemplate.root:
          _tok(Tok.xRoot);
          _ed.insertTok(Tok.openParen);
        default:
          if (linear != null) _fn(linear);
      }
      return;
    }
    final continues =
        t == MathTemplate.power || t == MathTemplate.fraction && _resultShown;
    _beforeInput(continues: continues);
    _ed.insertTemplate(t);
  }

  // ------------------------------------------------------------- key maps

  void _onPlain(CalcKey key) {
    final d = key.digit;
    if (d != null) {
      _tok(Tok.digits[d]);
      return;
    }
    switch (key) {
      case CalcKey.dot:
        _tok(Tok.point);
      case CalcKey.add:
        _tok(Tok.add);
      case CalcKey.subtract:
        _tok(Tok.subtract);
      case CalcKey.multiply:
        _tok(Tok.multiply);
      case CalcKey.divide:
        _tok(Tok.divide);
      case CalcKey.negative:
        _tok(Tok.negative);
      case CalcKey.openParen:
        _tok(Tok.openParen);
      case CalcKey.closeParen:
        _tok(Tok.closeParen);
      case CalcKey.exp:
        _tok(Tok.exp);
      case CalcKey.ans:
        _tok(Tok.ans);
      case CalcKey.square:
        _tok(Tok.square);
      case CalcKey.reciprocal:
        _tok(Tok.reciprocal);
      case CalcKey.degMinSec:
        _tok(Tok.dms);
      case CalcKey.sin:
        _fn(Tok.sin);
      case CalcKey.cos:
        _fn(Tok.cos);
      case CalcKey.tan:
        _fn(Tok.tan);
      case CalcKey.log:
        _fn(Tok.log);
      case CalcKey.ln:
        _fn(Tok.ln);
      case CalcKey.fraction:
        _template(MathTemplate.fraction);
      case CalcKey.sqrt:
        _template(MathTemplate.sqrt, linear: Tok.sqrt);
      case CalcKey.power:
        _template(MathTemplate.power);
      case CalcKey.logBase:
        if (mathInput) {
          _template(MathTemplate.logBase);
        } else {
          _tok(Tok.logBase);
        }
      case CalcKey.integrate:
        if (mathInput) {
          _template(MathTemplate.integral);
        } else {
          _tok(Tok.integral);
        }
      case CalcKey.hyp:
        _menu = _hypMenu();
      case CalcKey.rcl:
        _rcl = true;
      case CalcKey.mPlus:
        _memoryAdd(subtract: false);
      case CalcKey.eng:
        _engStep(left: false);
      case CalcKey.sd:
        _toggleSd();
      case CalcKey.equals:
        _execute();
      case CalcKey.ac:
        _clearInput();
      case CalcKey.del:
        _delete();
      case CalcKey.left:
        _cursorKey(left: true);
      case CalcKey.right:
        _cursorKey(left: false);
      case CalcKey.up:
        _vertical(up: true);
      case CalcKey.down:
        _vertical(up: false);
      case CalcKey.mode:
        _menu = _modeMenu();
      default:
        break; // CALC / CONST / comma: later milestones or not on this keypad.
    }
  }

  void _onShift(CalcKey key) {
    switch (key) {
      case CalcKey.sin:
        _fn(Tok.asin);
      case CalcKey.cos:
        _fn(Tok.acos);
      case CalcKey.tan:
        _fn(Tok.atan);
      case CalcKey.log:
        _template(MathTemplate.tenPow, linear: Tok.tenPow);
      case CalcKey.ln:
        _template(MathTemplate.ePow, linear: Tok.ePow);
      case CalcKey.square:
        _tok(Tok.cube);
      case CalcKey.reciprocal:
        _tok(Tok.factorial);
      case CalcKey.sqrt:
        _template(MathTemplate.cbrt, linear: Tok.cbrt);
      case CalcKey.power:
        _template(MathTemplate.root);
      case CalcKey.fraction:
        _template(MathTemplate.mixed);
      case CalcKey.logBase:
        if (mathInput) {
          _template(MathTemplate.sum);
        } else {
          _tok(Tok.sigma);
        }
      case CalcKey.integrate:
        if (mathInput) {
          _template(MathTemplate.derivative);
        } else {
          _tok(Tok.derivative);
        }
      case CalcKey.hyp:
        if (mathInput) {
          _template(MathTemplate.abs);
        } else {
          _fn(Tok.cAbs);
        }
      case CalcKey.openParen:
        _tok(Tok.percentOf);
      case CalcKey.closeParen:
        _tok(Tok.comma);
      case CalcKey.multiply:
        _tok(Tok.nPr);
      case CalcKey.divide:
        _tok(Tok.nCr);
      case CalcKey.add:
        _tok(Tok.pol);
      case CalcKey.subtract:
        _tok(Tok.rec);
      case CalcKey.d0:
        _fn(Tok.rnd);
      case CalcKey.dot:
        _tok(Tok.ran);
      case CalcKey.exp:
        _tok(Tok.pi);
      case CalcKey.d7:
        _askNumber('CONST', (n) {
          if (n >= 1 && n <= 40) _tok(Tok.constants[n - 1]);
        });
      case CalcKey.d8:
        _askNumber('CONV', (n) {
          if (n >= 1 && n <= 40) _tok(Tok.conversions[n - 1]);
        });
      case CalcKey.d9:
        _menu = _clrMenu();
      case CalcKey.ans:
        _menu = _drgMenu();
      case CalcKey.rcl:
        _sto = true;
      case CalcKey.mPlus:
        _memoryAdd(subtract: true);
      case CalcKey.eng:
        _engStep(left: true);
      case CalcKey.sd:
        if (_resultShown && _shownFraction() != null) _flipMixed = !_flipMixed;
      case CalcKey.degMinSec:
        // ← : show the result in degrees-minutes-seconds and back.
        if (_resultShown && _result != null) {
          final r = _result!;
          _result = r.isSexagesimal
              ? Value.dec(r.dec)
              : Value.sexagesimal(r.dec);
        }
      case CalcKey.equals:
        _execute(decimal: true);
      case CalcKey.del:
        if (!mathInput) _overwrite = !_overwrite;
      case CalcKey.ac:
        _off = true;
      case CalcKey.mode:
        _menu = _setupMenu1();
      default:
        break;
    }
  }

  void _onAlpha(CalcKey key) {
    final name = switch (key) {
      CalcKey.negative => 'A',
      CalcKey.degMinSec => 'B',
      CalcKey.hyp => 'C',
      CalcKey.sin => 'D',
      CalcKey.cos => 'E',
      CalcKey.tan => 'F',
      CalcKey.closeParen => 'X',
      CalcKey.sd => 'Y',
      CalcKey.mPlus => 'M',
      _ => null,
    };
    if (name != null) {
      _tok(_varTok(name));
      return;
    }
    switch (key) {
      case CalcKey.exp:
        _tok(Tok.e);
      case CalcKey.integrate:
        _tok(Tok.colon);
      case CalcKey.calc:
        _tok(Tok.eqSign);
      case CalcKey.dot:
        _tok(Tok.ranInt);
      default:
        break;
    }
  }

  static Tok _varTok(String n) => switch (n) {
    'A' => Tok.varA,
    'B' => Tok.varB,
    'C' => Tok.varC,
    'D' => Tok.varD,
    'E' => Tok.varE,
    'F' => Tok.varF,
    'X' => Tok.varX,
    'Y' => Tok.varY,
    _ => Tok.varM,
  };

  // ------------------------------------------------------------- memory

  void _onMemoryKey(CalcKey key) {
    final sto = _sto;
    _sto = _rcl = false;
    final name = switch (key) {
      CalcKey.negative => 'A',
      CalcKey.degMinSec => 'B',
      CalcKey.hyp => 'C',
      CalcKey.sin => 'D',
      CalcKey.cos => 'E',
      CalcKey.tan => 'F',
      CalcKey.closeParen => 'X',
      CalcKey.sd => 'Y',
      CalcKey.mPlus => 'M',
      _ => null,
    };
    if (name == null) return;
    if (sto) {
      // Evaluate what is on screen (or keep the shown result) and store it.
      if (!_resultShown && !_ed.isEmpty) _execute();
      if (_error != null) return;
      if (_result == null) return;
      _vars[name] = _result!;
      return;
    }
    // RCL shows the variable's value as a result.
    _ed.load(MathRow([TokItem(_varTok(name))]));
    _setResult(_vars[name]!);
  }

  void _memoryAdd({required bool subtract}) {
    if (!_resultShown && !_ed.isEmpty) {
      _execute();
      if (_error != null) return;
    }
    final v = _result ?? _ans;
    final m = _vars['M']!;
    _vars['M'] = subtract ? m - v : m + v;
  }

  // ------------------------------------------------------------- editing

  void _delete() {
    if (_resultShown) {
      _resultShown = false;
      _ed.cursor = MathCursor(const [], _ed.root.items.length);
      return;
    }
    if (_overwrite && !mathInput) {
      if (_ed.cursor.pos < _ed.row.items.length) {
        _ed.row.items.removeAt(_ed.cursor.pos);
      } else {
        _ed.delete();
      }
      return;
    }
    _ed.delete();
  }

  void _cursorKey({required bool left}) {
    if (_resultShown) {
      // Back to editing the calculation just done.
      _resultShown = false;
      _historyIndex = null;
      _ed.cursor = left
          ? MathCursor(const [], _ed.root.items.length)
          : MathCursor.start;
      return;
    }
    if (left) {
      _ed.left();
    } else {
      _ed.right();
    }
  }

  void _vertical({required bool up}) {
    if (!_resultShown) {
      if (mathInput) _ed.vertical(up: up);
      return;
    }
    // History: ▲ older, ▼ newer.
    if (_history.isEmpty) return;
    final current = _historyIndex ?? _history.length - 1;
    final next = up ? current - 1 : current + 1;
    if (next < 0 || next >= _history.length) return;
    _historyIndex = next;
    final h = _history[next];
    _ed.load(h.input);
    _setResult(h.result, record: false);
  }

  // ------------------------------------------------------------- results

  void _execute({bool decimal = false}) {
    if (_resultShown) {
      // = again repeats the calculation (with the new Ans).
      _resultShown = false;
    }
    if (_ed.isEmpty) return;
    final form = _ed.linearize();
    final ctx = EvalContext(
      ans: _ans,
      angle: angle,
      format: format,
      variables: _vars,
      improperFractions: improper,
      random: _random,
      polRecVars: const ('X', 'Y'),
      store: (n, v) => _vars[n] = v,
    );
    try {
      final v = evaluateValue(form.tokens, ctx);
      _setResult(v);
      _alternate = decimal;
    } on CalcError catch (e) {
      _error = _errorText(e.kind);
      _errorCursor = form.cursorFor(
        e.position ?? form.tokens.length,
        _ed.cursor,
      );
    }
  }

  void _setResult(Value v, {bool record = true}) {
    _result = v;
    _ans = v;
    _resultShown = true;
    _alternate = false;
    _flipMixed = false;
    _engExponent = null;
    if (record) {
      _history.add(_History(_ed.root.copy(), v));
      while (_history.fold<int>(0, (s, h) => s + h.bytes) > historyBytes &&
          _history.length > 1) {
        _history.removeAt(0);
      }
      _historyIndex = null;
    }
  }

  void _toggleSd() {
    if (!_resultShown || _result == null) return;
    _engExponent = null;
    _alternate = !_alternate;
  }

  void _engStep({required bool left}) {
    if (!_resultShown || _result == null || _result!.isComplex) return;
    final x = _result!.dec;
    final e = _engExponent ?? engExponentFor(x);
    _engExponent = _engExponent == null ? e : (left ? e + 3 : e - 3);
    if (_engExponent! > 99 || _engExponent! < -99) _engExponent = e;
  }

  /// Fraction the result should be shown as, or null for decimal.
  Frac? _shownFraction() {
    final r = _result;
    if (r == null || r.isComplex || r.isLinear || r.isSexagesimal) return null;
    if (_engExponent != null) return null;
    if (r.dec.isInteger) return null;
    final f = r.frac ?? Frac.approximate(r.dec);
    if (f == null) return null;
    // MathO shows exact fractions by default; LineIO / LineO show decimals
    // until S⇔D.
    final exactFirst = mathInput;
    return exactFirst != _alternate ? f : null;
  }

  static String _errorText(CalcErrorKind k) => switch (k) {
    CalcErrorKind.math => 'Math ERROR',
    CalcErrorKind.stack => 'Stack ERROR',
    CalcErrorKind.syntax => 'Syntax ERROR',
    CalcErrorKind.arg => 'Argument ERROR',
    CalcErrorKind.dim => 'Dimension ERROR',
    CalcErrorKind.cantSolve => "Can't Solve",
  };

  void _onErrorKey(CalcKey key) {
    switch (key) {
      case CalcKey.ac:
        _error = null;
        _clearInput();
      case CalcKey.left || CalcKey.right:
        _error = null;
        _resultShown = false;
        if (_errorCursor != null) _ed.moveTo(_errorCursor!);
      default:
        break;
    }
  }

  // ------------------------------------------------------------- menus

  void _onMenuKey(CalcKey key) {
    final m = _menu!;
    if (key == CalcKey.shift) {
      _shift = !_shift;
      return;
    }
    if (key == CalcKey.mode && _shift) {
      _shift = false;
      _menu = _setupMenu1();
      return;
    }
    _shift = false;
    final confirm = _pendingConfirm;
    if (confirm != null) {
      if (key == CalcKey.equals || key == CalcKey.ac) {
        _pendingConfirm = null;
        _menu = null;
        if (key == CalcKey.equals) confirm();
      }
      return;
    }
    if (m.lines.first == 'CONTRAST') {
      if (key == CalcKey.left || key == CalcKey.right) {
        contrast = (contrast + (key == CalcKey.right ? 1 : -1)).clamp(-5, 5);
        _menu = _contrastMenu();
      } else if (key == CalcKey.ac) {
        _menu = null;
      }
      return;
    }
    switch (key) {
      case CalcKey.ac:
        _menu = null;
      case CalcKey.down when m.next != null:
        _menu = m.next!();
      case CalcKey.up when m.prev != null:
        _menu = m.prev!();
      case CalcKey.mode:
        _menu = _modeMenu();
      default:
        final d = key.digit;
        final action = d == null ? null : m.actions[d];
        if (action != null) {
          _menu = null;
          action();
        }
    }
  }

  _Menu _modeMenu() => _Menu(
    const [
      '1:COMP  2:CMPLX',
      '3:STAT  4:BASE-N',
      '5:EQN   6:MATRIX',
      '7:TABLE 8:VECTOR',
    ],
    {for (final (i, m) in NaturalMode.values.indexed) i + 1: () => _setMode(m)},
  );

  void _setMode(NaturalMode m) {
    mode = m;
    _history.clear();
    _clearInput();
  }

  _Menu _setupMenu1() => _Menu(
    const [
      '1:MthIO 2:LineIO',
      '3:Deg   4:Rad',
      '5:Gra   6:Fix',
      '7:Sci   8:Norm',
    ],
    {
      1: () => _menu = _Menu(
        const ['1:MathO 2:LineO'],
        {
          1: () => _setIO(math: true, out: true),
          2: () => _setIO(math: true, out: false),
        },
      ),
      2: () => _setIO(math: false, out: false),
      3: () => angle = AngleUnit.deg,
      4: () => angle = AngleUnit.rad,
      5: () => angle = AngleUnit.gra,
      6: () =>
          _askDigit('Fix 0~9?', 0, 9, (n) => format = DisplayFormat.fix(n)),
      7: () => _askDigit(
        'Sci 0~9?',
        0,
        9,
        (n) => format = DisplayFormat.sci(n == 0 ? 10 : n),
      ),
      8: () => _askDigit(
        'Norm 1~2?',
        1,
        2,
        (n) => format = n == 1
            ? const DisplayFormat.norm1()
            : const DisplayFormat.norm2(),
      ),
    },
    next: _setupMenu2,
  );

  _Menu _setupMenu2() => _Menu(
    const ['1:ab/c  2:d/c', '3:CMPLX 4:STAT', '5:Disp  6:◀CONT▶'],
    {
      1: () => improper = false,
      2: () => improper = true,
      3: () => _menu = _Menu(
        const ['1:a+bi  2:r∠θ'],
        {1: () => polarComplex = false, 2: () => polarComplex = true},
      ),
      4: () => _menu = _Menu(
        const ['Frequency?', '1:ON    2:OFF'],
        {1: () => statFrequency = true, 2: () => statFrequency = false},
      ),
      5: () => _menu = _Menu(
        const ['1:Dot   2:Comma'],
        {1: () => decimalComma = false, 2: () => decimalComma = true},
      ),
      6: () => _menu = _contrastMenu(),
    },
    prev: _setupMenu1,
  );

  _Menu _contrastMenu() => _Menu([
    'CONTRAST',
    'LIGHT       DARK',
    '[◀]         [▶]',
    _contrastBar(),
  ], const {});

  String _contrastBar() {
    final n = contrast + 5;
    return '${'■' * n}${'.' * (10 - n)}';
  }

  void _setIO({required bool math, required bool out}) {
    if (mathInput != math) {
      _history.clear();
      _clearInput();
    }
    mathInput = math;
    mathOutput = out;
    if (math) _overwrite = false;
  }

  _Menu _clrMenu() => _Menu(
    const ['Clear?', '1:Setup 2:Memory', '3:All'],
    {
      1: () => _confirm('Reset Setup?', _resetSetup),
      2: () => _confirm('Clear Memory?', _clearMemory),
      3: () => _confirm('Reset All?', resetAll),
    },
  );

  void _confirm(String question, void Function() action) {
    _menu = _Menu([question, '', '[=] :Yes', '[AC]:Cancel'], {});
    _pendingConfirm = action;
  }

  void Function()? _pendingConfirm;

  void _resetSetup() {
    mode = NaturalMode.comp;
    mathInput = mathOutput = true;
    angle = AngleUnit.deg;
    format = const DisplayFormat.norm1();
    improper = true;
    decimalComma = polarComplex = statFrequency = false;
    contrast = 0;
    _overwrite = false;
    _history.clear();
    _clearInput();
  }

  void _clearMemory() {
    for (final k in _vars.keys) {
      _vars[k] = Value.zero;
    }
    _ans = Value.zero;
  }

  /// CLR All.
  void resetAll() {
    _resetSetup();
    _clearMemory();
  }

  _Menu _hypMenu() => _Menu(
    const ['1:sinh  2:cosh', '3:tanh  4:sinh⁻¹', '5:cosh⁻¹6:tanh⁻¹'],
    {
      1: () => _fn(Tok.sinh),
      2: () => _fn(Tok.cosh),
      3: () => _fn(Tok.tanh),
      4: () => _fn(Tok.asinh),
      5: () => _fn(Tok.acosh),
      6: () => _fn(Tok.atanh),
    },
  );

  _Menu _drgMenu() => _Menu(
    const ['1:°   2:r   3:g'],
    {
      1: () => _tok(Tok.degMark),
      2: () => _tok(Tok.radMark),
      3: () => _tok(Tok.graMark),
    },
  );

  // ------------------------------------------------------------- prompts

  /// One digit for Fix / Sci / Norm.
  void _askDigit(String prompt, int lo, int hi, void Function(int) done) {
    _numberPrompt = prompt;
    _numberDigits = '';
    _numberDone = (n) {
      if (n >= lo && n <= hi) done(n);
    };
    _numberWidth = 1;
  }

  /// Two digits for CONST / CONV.
  void _askNumber(String prompt, void Function(int) done) {
    _numberPrompt = prompt;
    _numberDigits = '';
    _numberDone = done;
    _numberWidth = 2;
  }

  int _numberWidth = 1;

  void _onNumberPrompt(CalcKey key) {
    if (key == CalcKey.ac) {
      _numberPrompt = null;
      return;
    }
    final d = key.digit;
    if (d == null) return;
    _numberDigits += '$d';
    if (_numberDigits.length < _numberWidth) return;
    final done = _numberDone!;
    final n = int.parse(_numberDigits);
    _numberPrompt = null;
    done(n);
  }

  // ------------------------------------------------------------- screen

  DotScreen get screen {
    if (_off) return DotScreen.off;
    final bmp = DotBitmap(DotScreen.width, DotScreen.height);
    final ind = <Indicator>{
      if (_shift) Indicator.shift,
      if (_alpha) Indicator.alpha,
      if (!_vars['M']!.dec.isZero || _vars['M']!.isComplex) Indicator.memory,
      if (_sto) Indicator.sto,
      if (_rcl) Indicator.rcl,
      switch (angle) {
        AngleUnit.deg => Indicator.deg,
        AngleUnit.rad => Indicator.rad,
        AngleUnit.gra => Indicator.gra,
      },
      if (format.mode == DisplayMode.fix) Indicator.fix,
      if (format.mode == DisplayMode.sci) Indicator.sci,
      if (mathInput) Indicator.math,
    };
    CursorRect? cursor;
    final text = StringBuffer();

    if (_error != null) {
      bmp.text(0, 0, _error!);
      bmp.text(0, 12, '[AC]  :Cancel');
      bmp.text(0, 21, '[◀][▶]:Goto');
      text.write('$_error | [AC]  :Cancel | [◀][▶]:Goto');
    } else if (_numberPrompt != null) {
      bmp.text(0, 0, _numberPrompt!);
      bmp.text(0, 24, _numberDigits);
      text.write('$_numberPrompt $_numberDigits');
    } else if (_menu != null) {
      final m = _menu!;
      for (var i = 0; i < m.lines.length && i < 4; i++) {
        bmp.text(0, i * 8, m.lines[i]);
      }
      if (m.next != null) ind.add(Indicator.scrollDown);
      if (m.prev != null) ind.add(Indicator.scrollUp);
      text.write(m.lines.join(' | '));
    } else {
      cursor = _paintCalculation(bmp, text);
      if (_resultShown && _history.isNotEmpty) {
        final i = _historyIndex ?? _history.length - 1;
        if (i > 0) ind.add(Indicator.scrollUp);
        if (i < _history.length - 1) ind.add(Indicator.scrollDown);
      }
    }
    return DotScreen(
      dots: bmp,
      indicators: ind,
      cursor: cursor,
      contrast: contrast,
      text: text.toString(),
    );
  }

  CursorRect? _paintCalculation(DotBitmap bmp, StringBuffer text) {
    final layout = MathLayout(_ed.root);
    text.write(_ed.root.toString());
    final editing = !_resultShown;

    // Horizontal scroll keeps the cursor in view while editing.
    final probe = DotBitmap(layout.width + 8, layout.height);
    final at = layout.paint(probe, 0, 0, cursor: editing ? _ed.cursor : null);
    if (editing && at != null) {
      if (at.x - _scrollX > DotScreen.width - 4) {
        _scrollX = at.x - DotScreen.width + 4;
      } else if (at.x - _scrollX < 0) {
        _scrollX = at.x;
      }
    } else if (!editing) {
      _scrollX = 0;
    }
    var cursor = layout.paint(
      bmp,
      1 - _scrollX,
      0,
      cursor: editing ? _ed.cursor : null,
    );
    if (editing && _ed.isEmpty) cursor = const CursorRect(1, 0, 7);

    if (_resultShown && _result != null) {
      text.write(' = ');
      _paintResult(bmp, text);
    }
    return editing ? cursor : null;
  }

  void _paintResult(DotBitmap bmp, StringBuffer text) {
    final r = _result!;
    final settings = DisplaySettings(
      format: format,
      improperFractions: improper,
      decimalComma: decimalComma,
      leadingZeroCounts: false,
    );
    final frac = _shownFraction();
    MathRow row;
    if (frac != null) {
      final improperView = improper != _flipMixed;
      row = _fractionRow(
        frac,
        improperView,
        linear: !(mathInput && mathOutput),
      );
    } else {
      final f = r.isSexagesimal
          ? formatValue(r, settings, view: ResultView.sexagesimal)
          : formatValue(
              r,
              settings,
              view: ResultView.decimal,
              engExponent: _engExponent,
            );
      row = _decimalRow(f);
    }
    text.write(row.toString());
    final layout = MathLayout(row);
    // Clear the result area, then draw right-aligned on the bottom row.
    final top = DotScreen.height - layout.height;
    for (var y = top - 1; y < DotScreen.height; y++) {
      for (var x = 0; x < DotScreen.width; x++) {
        bmp.set(x, y, false);
      }
    }
    layout.paint(bmp, DotScreen.width - layout.width - 1, top);
  }

  MathRow _fractionRow(Frac f, bool improperView, {required bool linear}) {
    final items = <MathItem>[];
    final neg = f.isNegative;
    final n = f.n.abs(), d = f.d;
    if (neg) items.add(TokItem(Tok.negative));
    if (linear) {
      if (improperView || n < d) {
        items
          ..addAll(_digitItems('$n'))
          ..add(TokItem(Tok.fracSep))
          ..addAll(_digitItems('$d'));
      } else {
        items
          ..addAll(_digitItems('${n ~/ d}'))
          ..add(TokItem(Tok.fracSep))
          ..addAll(_digitItems('${n % d}'))
          ..add(TokItem(Tok.fracSep))
          ..addAll(_digitItems('$d'));
      }
      return MathRow(items);
    }
    if (improperView || n < d) {
      items.add(
        TemplateItem(MathTemplate.fraction, [
          MathRow(_digitItems('$n')),
          MathRow(_digitItems('$d')),
        ]),
      );
    } else {
      items.add(
        TemplateItem(MathTemplate.mixed, [
          MathRow(_digitItems('${n ~/ d}')),
          MathRow(_digitItems('${n % d}')),
          MathRow(_digitItems('$d')),
        ]),
      );
    }
    return MathRow(items);
  }

  MathRow _decimalRow(FormattedNumber f) {
    var m = f.mantissa;
    if (m.endsWith('.')) m = m.substring(0, m.length - 1);
    if (decimalComma) m = m.replaceAll('.', ',');
    final items = _digitItems(m);
    final exp = f.exponent;
    if (f.engSymbol != null) {
      // Not used on these models (no EngON).
    }
    if (exp != null) {
      final e = int.parse(exp);
      items
        ..add(TokItem(Tok.multiply))
        ..add(TemplateItem(MathTemplate.tenPow, [MathRow(_digitItems('$e'))]));
    }
    return MathRow(items);
  }

  static List<MathItem> _digitItems(String s) => [
    for (final c in s.split(''))
      TokItem(switch (c) {
        '-' => Tok.negative,
        '.' => Tok.point,
        ',' => Tok.comma,
        '°' => Tok.dms,
        _ when int.tryParse(c) != null => Tok.digits[int.parse(c)],
        _ => Tok.point,
      }),
  ];

  // ------------------------------------------------------------- persistence

  Map<String, Object?> saveState() => {
    'v': 1,
    'mathInput': mathInput,
    'mathOutput': mathOutput,
    'angle': angle.name,
    'format': '${format.mode.name}:${format.digits}',
    'improper': improper,
    'comma': decimalComma,
    'polar': polarComplex,
    'freq': statFrequency,
    'contrast': contrast,
    'vars': {for (final e in _vars.entries) e.key: e.value.dec.toString()},
    'ans': _ans.dec.toString(),
  };

  void restoreState(Map<String, Object?> s) {
    if (s['v'] != 1) return;
    mathInput = s['mathInput'] != false;
    mathOutput = s['mathOutput'] != false;
    final a = s['angle'];
    if (a is String) angle = AngleUnit.values.byName(a);
    final f = s['format'];
    if (f is String) {
      final [m, d] = f.split(':');
      final digits = int.parse(d);
      format = switch (m) {
        'fix' => DisplayFormat.fix(digits),
        'sci' => DisplayFormat.sci(digits),
        _ =>
          digits == 2
              ? const DisplayFormat.norm2()
              : const DisplayFormat.norm1(),
      };
    }
    improper = s['improper'] != false;
    decimalComma = s['comma'] == true;
    polarComplex = s['polar'] == true;
    statFrequency = s['freq'] == true;
    final c = s['contrast'];
    if (c is int) contrast = c;
    final vars = s['vars'];
    if (vars is Map) {
      for (final MapEntry(:key, :value) in vars.entries) {
        if (key is String && value is String && _vars.containsKey(key)) {
          _vars[key] = Value.dec(Dec.parse(value));
        }
      }
    }
    final ans = s['ans'];
    if (ans is String) _ans = Value.dec(Dec.parse(ans));
  }
}
