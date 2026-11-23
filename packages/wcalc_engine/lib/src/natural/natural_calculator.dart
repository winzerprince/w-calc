import 'dart:math' as math;

import '../angle_unit.dart';
import '../calc_engine.dart';
import '../calc_key.dart';
import '../display_state.dart';
import '../eval/evaluator.dart';
import '../format/number_format.dart';
import '../format/value_format.dart';
import '../input/token.dart';
import '../lcd/dot_bitmap.dart';
import '../eval/solve.dart';
import '../number/dec.dart';
import '../number/frac.dart';
import '../number/surd.dart';
import '../number/value.dart';
import 'dot_screen.dart';
import 'math_input.dart';
import 'math_render.dart';
import 'result_forms.dart';

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

/// CALC / SOLVE prompts for the variables of a stored expression.
final class _Equation {
  _Equation({
    required this.solve,
    required this.input,
    required this.tokens,
    required this.variables,
  });

  final bool solve;
  final MathRow input;
  final List<Tok> tokens;

  /// Variable names prompted, in order (SOLVE: X last, as the start value).
  final List<String> variables;
  int index = 0;
  bool prompting = true;
  String typed = '';

  /// SOLVE result: X and left − right.
  Value? solution;
  Dec? residual;
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
class NaturalCalculator implements CalcEngine {
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

  /// Result came from SHIFT = (S⇔D then offers fraction / π forms only).
  bool _decimalFirst = false;

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

  _Equation? _equation;

  /// ▶r∠θ / ▶a+bi at the end of the last calculation (null: setup).
  bool? _polarOverride;

  final List<_History> _history = [];
  int? _historyIndex;
  static const historyBytes = 200;

  int _scrollX = 0;

  Map<String, Value> get variables => Map.unmodifiable(_vars);
  Value get ans => _ans;

  // ------------------------------------------------------------- keys
  @override
  bool isSlowKey(CalcKey key) =>
      key == CalcKey.equals && !_shift && _menu == null && _error == null;

  @override
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
    if (_equation != null && _onEquationKey(key, shift: shift)) return;
    if (!shift && !alpha && key == CalcKey.calc) {
      _startEquation(solve: false);
      return;
    }
    if (shift && key == CalcKey.calc) {
      _startEquation(solve: true);
      return;
    }
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
    _equation = null;
    _polarOverride = null;
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
      case CalcKey.eng when mode == NaturalMode.cmplx:
        _tok(Tok.imagUnit);
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
      case CalcKey.d2 when mode == NaturalMode.cmplx:
        _menu = _cmplxMenu();
      case CalcKey.negative when mode == NaturalMode.cmplx:
        _tok(Tok.angle);
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
      case CalcKey.eng when mode == NaturalMode.cmplx:
        _tok(Tok.imagUnit);
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
    final ctx = _context();
    var tokens = form.tokens;
    _polarOverride = null;
    if (tokens.isNotEmpty && tokens.last.kind == TokKind.formatCommand) {
      _polarOverride = tokens.last == Tok.toPolar;
      tokens = tokens.sublist(0, tokens.length - 1);
    }
    try {
      final v = _evalStatements(tokens, ctx);
      _setResult(v);
      _decimalFirst = decimal;
    } on CalcError catch (e) {
      _error = _errorText(e.kind);
      _errorCursor = form.cursorFor(
        e.position ?? form.tokens.length,
        _ed.cursor,
      );
    }
  }

  /// Multi-statements (A:B): evaluated in order, the last one shown.
  Value _evalStatements(List<Tok> tokens, EvalContext ctx) {
    Value? last;
    var start = 0;
    for (var i = 0; i <= tokens.length; i++) {
      if (i == tokens.length || tokens[i] == Tok.colon) {
        try {
          last = evaluateValue(
            tokens.sublist(start, i),
            _ctxWithAns(ctx, last),
          );
        } on CalcError catch (e) {
          throw CalcError(e.kind, start + (e.position ?? 0));
        }
        start = i + 1;
      }
    }
    return last!;
  }

  EvalContext _ctxWithAns(EvalContext c, Value? ans) => ans == null
      ? c
      : EvalContext(
          ans: ans,
          angle: c.angle,
          format: c.format,
          variables: c.variables,
          improperFractions: c.improperFractions,
          random: c.random,
          polRecVars: c.polRecVars,
          exactForms: c.exactForms,
          functionParens: c.functionParens,
          store: c.store,
        );

  EvalContext _context() => EvalContext(
    ans: _ans,
    angle: angle,
    format: format,
    variables: _vars,
    improperFractions: improper,
    random: _random,
    polRecVars: const ('X', 'Y'),
    exactForms: true,
    functionParens: true,
    store: (n, v) => _vars[n] = v,
  );

  // ------------------------------------------------------------- CALC / SOLVE

  void _startEquation({required bool solve}) {
    if (mode != NaturalMode.comp && mode != NaturalMode.cmplx) return;
    if (solve && mode != NaturalMode.comp) return;
    if (_ed.isEmpty) return;
    final tokens = _ed.linearize().tokens;
    final names = <String>[];
    var skipFirst = false;
    if (!solve &&
        tokens.length > 1 &&
        tokens[0].kind == TokKind.variable &&
        tokens[1] == Tok.eqSign) {
      skipFirst = true; // Y = … assigns to Y.
    }
    for (var i = skipFirst ? 2 : 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind == TokKind.variable && !names.contains(t.text)) {
        names.add(t.text);
      }
    }
    if (solve) {
      if (!names.contains('X')) {
        _error = 'Variable ERROR';
        _errorCursor = _ed.cursor;
        return;
      }
      names
        ..remove('X')
        ..add('X');
    }
    _resultShown = false;
    _equation = _Equation(
      solve: solve,
      input: _ed.root.copy(),
      tokens: tokens,
      variables: names,
    );
    if (names.isEmpty) _calcResult(_equation!);
  }

  /// Keys while CALC / SOLVE is active. False ends the session and lets the
  /// key work normally.
  bool _onEquationKey(CalcKey key, {required bool shift}) {
    final eq = _equation!;
    if (key == CalcKey.ac) {
      _equation = null;
      _resultShown = false;
      return true;
    }
    if (!eq.prompting) {
      final again =
          (!eq.solve && !shift && key == CalcKey.calc) ||
          (!eq.solve && key == CalcKey.equals) ||
          (eq.solve &&
              (key == CalcKey.equals || (shift && key == CalcKey.calc)));
      if (again) {
        eq
          ..prompting = true
          ..index = 0
          ..typed = '';
        _resultShown = false;
        return true;
      }
      _equation = null;
      return false;
    }
    final d = key.digit;
    if (!shift && d != null) {
      eq.typed += '$d';
      return true;
    }
    switch (key) {
      case CalcKey.dot when !shift:
        eq.typed += '.';
      case CalcKey.negative when !shift:
        eq.typed += '-';
      case CalcKey.exp when !shift:
        eq.typed += 'E';
      case CalcKey.del:
        if (eq.typed.isNotEmpty) {
          eq.typed = eq.typed.substring(0, eq.typed.length - 1);
        }
      case CalcKey.up when eq.index > 0:
        eq.typed = '';
        eq.index--;
      case CalcKey.down when eq.index < eq.variables.length - 1:
        eq.typed = '';
        eq.index++;
      case CalcKey.equals:
        if (!_commitTyped(eq)) return true;
        if (eq.index < eq.variables.length - 1) {
          eq.index++;
        } else if (eq.solve) {
          _solve(eq);
        } else {
          _calcResult(eq);
        }
      default:
        break;
    }
    return true;
  }

  bool _commitTyped(_Equation eq) {
    if (eq.typed.isEmpty) return true;
    final toks = <Tok>[
      for (final c in eq.typed.split(''))
        switch (c) {
          '.' => Tok.point,
          '-' => Tok.negative,
          'E' => Tok.exp,
          _ => Tok.digits[int.parse(c)],
        },
    ];
    try {
      _vars[eq.variables[eq.index]] = evaluateValue(toks, _context());
      eq.typed = '';
      return true;
    } on CalcError catch (e) {
      _equation = null;
      _error = _errorText(e.kind);
      _errorCursor = _ed.cursor;
      return false;
    }
  }

  void _calcResult(_Equation eq) {
    var tokens = eq.tokens;
    String? target;
    if (tokens.length > 1 &&
        tokens[0].kind == TokKind.variable &&
        tokens[1] == Tok.eqSign) {
      target = tokens[0].text;
      tokens = tokens.sublist(2);
    }
    try {
      final v = _evalStatements(tokens, _context());
      if (target != null) _vars[target] = v;
      _ed.load(eq.input);
      _setResult(v);
      eq.prompting = false;
    } on CalcError catch (e) {
      _equation = null;
      _ed.load(eq.input);
      _error = _errorText(e.kind);
      _errorCursor = _ed.cursor;
    }
  }

  void _solve(_Equation eq) {
    final tokens = eq.tokens;
    final bad = tokens.any(
      (t) =>
          t == Tok.integral ||
          t == Tok.derivative ||
          t == Tok.sigma ||
          t == Tok.pol ||
          t == Tok.rec ||
          t == Tok.colon,
    );
    final at = tokens.indexOf(Tok.eqSign);
    if (bad || tokens.lastIndexOf(Tok.eqSign) != at) {
      _equation = null;
      _error = 'Syntax ERROR';
      _errorCursor = _ed.cursor;
      return;
    }
    final left = at < 0 ? tokens : tokens.sublist(0, at);
    final right = at < 0 ? const <Tok>[] : tokens.sublist(at + 1);
    Dec diff(Dec x) {
      final saved = _vars['X']!;
      _vars['X'] = Value.dec(x);
      try {
        final l = evaluateValue(left, _context()).dec;
        final r = right.isEmpty
            ? Dec.zero
            : evaluateValue(right, _context()).dec;
        return l - r;
      } finally {
        _vars['X'] = saved;
      }
    }

    try {
      final x = newtonSolve(diff, _vars['X']!.dec);
      final v = Value.dec(x);
      _vars['X'] = v;
      eq
        ..solution = v
        ..residual = diff(x)
        ..prompting = false;
      _ed.load(eq.input);
      _setResult(v);
    } on CalcError {
      _equation = null;
      _ed.load(eq.input);
      _error = "Can't Solve";
      _errorCursor = _ed.cursor;
    }
  }

  _Menu _cmplxMenu() => _Menu(
    const ['1:arg    2:Conjg', '3:▶r∠θ   4:▶a+bi'],
    {
      1: () => _fn(Tok.cArg),
      2: () => _fn(Tok.conjg),
      3: () => _tok(Tok.toPolar),
      4: () => _tok(Tok.toRect),
    },
  );

  void _setResult(Value v, {bool record = true}) {
    _result = v;
    _ans = v;
    _resultShown = true;
    _alternate = false;
    _decimalFirst = false;
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

  /// Exact form the result is shown in, or null for a decimal.
  ExactForm? _shownForm() {
    final r = _result;
    if (r == null || _engExponent != null) return null;
    final mathOut = mathInput && mathOutput;
    // Exact first on MathO / LineO; decimal first on LineIO and after SHIFT =.
    final exactFirst = mathInput && !_decimalFirst;
    if (exactFirst == _alternate) return null;
    final form = exactFormOf(r, surd: mathOut && !_decimalFirst, pi: mathOut);
    return form;
  }

  Frac? _shownFraction() => switch (_shownForm()) {
    FractionForm(:final value) => value,
    _ => null,
  };

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
    _equation = null;
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
  @override
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
      if (mode == NaturalMode.cmplx) Indicator.cmplx,
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
    } else if (_equation case final eq? when eq.prompting) {
      final name = eq.variables[eq.index];
      final isStart = eq.solve && name == 'X';
      if (isStart) bmp.text(0, 0, 'Solve for X');
      bmp.text(0, isStart ? 12 : 0, '$name?');
      final shown = eq.typed.isNotEmpty
          ? eq.typed
          : _plainDecimal(_vars[name]!);
      final w = textWidth(shown);
      bmp.text(DotScreen.width - w - 1, 24, shown);
      text.write('${isStart ? 'Solve for X | ' : ''}$name? $shown');
    } else if (_equation case final eq?
        when eq.solve && eq.solution != null && _resultShown) {
      MathLayout(eq.input).paint(bmp, 1, 0);
      final x = _plainDecimal(eq.solution!);
      final lr = _plainDecimal(Value.dec(eq.residual!));
      bmp.text(0, 14, 'X=');
      bmp.text(DotScreen.width - textWidth(x) - 1, 14, x);
      bmp.text(0, 24, 'L-R=');
      bmp.text(DotScreen.width - textWidth(lr) - 1, 24, lr);
      text.write('${eq.input} | X= $x | L-R= $lr');
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
    final form = r.isComplex ? null : _shownForm();
    MathRow row;
    if (r.isComplex) {
      row = _complexRow(r);
    } else if (form is FractionForm) {
      final improperView = improper != _flipMixed;
      row = _fractionRow(
        form.value,
        improperView,
        linear: !(mathInput && mathOutput),
      );
    } else if (form is SurdForm) {
      row = _surdRow(form.value);
    } else if (form is PiForm) {
      row = _piRow(form.coefficient);
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

  /// Decimal text in the current format (prompts, SOLVE screen).
  String _plainDecimal(Value v) {
    final f = formatValue(
      v,
      DisplaySettings(format: format, leadingZeroCounts: false),
      view: ResultView.decimal,
    );
    var m = f.mantissa;
    if (m.endsWith('.')) m = m.substring(0, m.length - 1);
    if (decimalComma) m = m.replaceAll('.', ',');
    return f.exponent == null ? m : '$m×10^${int.parse(f.exponent!)}';
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

  /// (n₀ ± n₁√b₁ ± …)/d, rational part first; a lone negative term puts the
  /// minus sign in front of the fraction.
  MathRow _surdRow(Surd s) {
    final d = s.terms.values.fold(BigInt.one, (l, c) => l * c.d ~/ l.gcd(c.d));
    final parts = <(BigInt, BigInt)>[
      if (s.terms.containsKey(BigInt.one))
        (BigInt.one, (s.terms[BigInt.one]! * Frac.fromInt(d)).n),
      for (final (b, c) in s.radicals) (b, (c * Frac.fromInt(d)).n),
    ];
    final single = parts.length == 1;
    final leadingMinus = single && parts.single.$2.isNegative;
    final num = <MathItem>[];
    for (final (i, (b, n)) in parts.indexed) {
      if (n.isNegative && !(single && leadingMinus)) {
        num.add(TokItem(i == 0 ? Tok.negative : Tok.subtract));
      } else if (i > 0) {
        num.add(TokItem(Tok.add));
      }
      final m = n.abs();
      if (b == BigInt.one) {
        num.addAll(_digitItems('$m'));
      } else {
        if (m != BigInt.one) num.addAll(_digitItems('$m'));
        num.add(TemplateItem(MathTemplate.sqrt, [MathRow(_digitItems('$b'))]));
      }
    }
    final items = <MathItem>[if (leadingMinus) TokItem(Tok.negative)];
    if (d == BigInt.one) {
      items.addAll(num);
    } else {
      items.add(
        TemplateItem(MathTemplate.fraction, [
          MathRow(num),
          MathRow(_digitItems('$d')),
        ]),
      );
    }
    return MathRow(items);
  }

  /// a+bi or r∠θ, each part in its exact form when one fits.
  MathRow _complexRow(Value v) {
    final polar = _polarOverride ?? polarComplex;
    final exact = mathInput && mathOutput && !_alternate && !_decimalFirst;
    MathRow part(Dec x) {
      if (exact) {
        final f = exactFormOf(Value.dec(x));
        switch (f) {
          case FractionForm(:final value):
            return _fractionRow(value, true, linear: false);
          case SurdForm(:final value):
            return _surdRow(value);
          case PiForm(:final coefficient):
            return _piRow(coefficient);
          case null:
            break;
        }
      }
      return _decimalRow(
        formatValue(
          Value.dec(x),
          DisplaySettings(format: format, leadingZeroCounts: false),
          view: ResultView.decimal,
        ),
      );
    }

    if (polar) {
      final r = v.magnitude();
      final theta = v.argument(angle);
      return MathRow([
        ...part(r).items,
        TokItem(Tok.angle),
        ...part(theta).items,
      ]);
    }
    final re = v.dec, im = v.imag;
    final items = <MathItem>[if (!re.isZero) ...part(re).items];
    if (!im.isZero) {
      final mag = im.abs();
      if (im.isNegative) {
        items.add(TokItem(re.isZero ? Tok.negative : Tok.subtract));
      } else if (!re.isZero) {
        items.add(TokItem(Tok.add));
      }
      if (mag != Dec.one) items.addAll(part(mag).items);
      items.add(TokItem(Tok.imagUnit));
    }
    return MathRow(items);
  }

  /// (p/q)π shown as pπ over q.
  MathRow _piRow(Frac k) {
    final p = k.n.abs();
    final num = <MathItem>[
      if (p != BigInt.one) ..._digitItems('$p'),
      TokItem(Tok.pi),
    ];
    return MathRow([
      if (k.isNegative) TokItem(Tok.negative),
      if (k.d == BigInt.one)
        ...num
      else
        TemplateItem(MathTemplate.fraction, [
          MathRow(num),
          MathRow(_digitItems('${k.d}')),
        ]),
    ]);
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

  @override
  String? get copyText {
    final r = _result;
    if (!_resultShown || r == null || _error != null || r.isLinear) return null;
    if (r.isComplex) return null;
    final f = formatValue(
      r,
      DisplaySettings(format: format, leadingZeroCounts: false),
      view: ResultView.decimal,
    );
    var m = f.mantissa;
    if (m.endsWith('.')) m = m.substring(0, m.length - 1);
    return f.exponent == null ? m : '${m}E${f.exponent}';
  }

  // ------------------------------------------------------------- persistence

  @override
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

  @override
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
