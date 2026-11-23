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
import '../eqn/solvers.dart';
import '../eval/solve.dart';
import '../graph/graph_math.dart';
import '../number/dec.dart';
import '../number/frac.dart';
import '../number/surd.dart';
import '../number/value.dart';
import '../stats/stats.dart';
import 'dot_screen.dart';
import 'math_input.dart';
import 'math_render.dart';
import 'result_forms.dart';

/// Calculation modes of the textbook-display models (MODE 1-8).
enum NaturalMode { comp, cmplx, stat, base, eqn, matrix, table, vector }

/// How the calculation screen is laid out.
enum NaturalProfile {
  /// One expression on top, its result at the bottom right (96 × 31).
  textbook,

  /// Four text lines with the history above the current line: each entry
  /// left, its result right-aligned (on the same line when it fits).
  multiLine,

  /// Classic two-line dot display: one scrolling entry line (÷ as `/`,
  /// × as `*`), a tall result line with a trailing point on whole numbers,
  /// fractions as `14/15` or `7u1/8`, no √ / π forms.
  twoLine,
}

/// EQN types in MODE 5 menu order.
enum EqnType { lin2, lin3, quad, cubic, lin4 }

/// STAT calculation types in MODE 3 menu order.
enum StatType { oneVar, lin, quad, log, eExp, abExp, pwr, inv }

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
  NaturalCalculator({
    math.Random? random,
    this.profile = NaturalProfile.textbook,
    Set<NaturalMode>? modes,
    this.bigLinear = false,
    this.listNames = false,
    this.menuCursor = false,
    this.disabled = const {},
  }) : _random = random ?? math.Random(),
       modes = modes ?? NaturalMode.values.toSet();

  /// Screen layout of this model.
  final NaturalProfile profile;

  /// Modes this model offers on its MODE menu.
  final Set<NaturalMode> modes;

  /// Statistics editor columns named L1, L2, L3 (list-style models).
  final bool listNames;

  /// Functions a simpler model does not have: (key, modifier) pairs with
  /// modifier 0 = plain, 1 = SHIFT, 2 = ALPHA. Such presses do nothing.
  final Set<(CalcKey, int)> disabled;

  /// Menus show option names in rows with a highlight moved by ◀ ▶ and
  /// chosen with = (numbers still work).
  final bool menuCursor;

  int _menuIndex = 0;
  _Menu? _menuSeen;

  /// (number, label) items of a menu, from its "n:label" lines.
  static List<(int, String)> _items(_Menu m) => [
    for (final line in m.lines)
      for (final match in RegExp(r'(\d+):(.*?)(?=\s+\d+:|$)').allMatches(line))
        (int.parse(match.group(1)!), match.group(2)!.trim()),
  ];

  /// Four matrices up to 4 × 4 (MatA–MatD), four vectors and simultaneous
  /// equations with four unknowns.
  final bool bigLinear;

  List<String> get _letters =>
      bigLinear ? const ['A', 'B', 'C', 'D'] : const ['A', 'B', 'C'];

  final math.Random _random;

  // ------------------------------------------------------------- setup
  NaturalMode mode = NaturalMode.comp;

  /// MthIO (true) or LineIO.
  bool mathInput = true;

  /// STAT, BASE-N, MATRIX and VECTOR always use Linear display.
  bool get _mathIO =>
      mathInput &&
      profile != NaturalProfile.twoLine &&
      mode != NaturalMode.stat &&
      mode != NaturalMode.base &&
      mode != NaturalMode.matrix &&
      mode != NaturalMode.vector;

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

  // EQN
  EqnType? _eqnType;
  List<List<Value>> _coef = [];
  int _eRow = 0;
  int _eCol = 0;
  List<Value>? _solutions;
  int _solIndex = 0;

  // MATRIX / VECTOR
  final Map<String, Value> _linear = {};

  /// Variable shown in the grid editor (MatA … VctAns), or null.
  String? _grid;
  int _gRow = 0;
  int _gCol = 0;

  Map<String, Value> get linearVariables => Map.unmodifiable(_linear);

  // BASE-N
  int _base = 10;

  // TABLE
  /// Start / End / Step prompt (0-2) while setting up the table.
  int? _tablePrompt;
  String _tableTyped = '';
  final List<Dec> _tableRange = [Dec.one, Dec.fromInt(5), Dec.one];
  List<(Dec, Value?)>? _table;
  int _tRow = 0;
  int _tCol = 0;
  MathRow? _tableFn;

  // STAT
  StatType statType = StatType.oneVar;
  final StatData _stat = StatData();
  bool _editor = false;
  int _row = 0;
  int _col = 0;
  int _top = 0;
  String _cell = '';

  bool get _paired => statType != StatType.oneVar;
  int get _cols => 1 + (_paired ? 1 : 0) + (statFrequency ? 1 : 0);
  int get _maxRows => switch (_cols) {
    1 => 80,
    2 => 40,
    _ => 26,
  };

  /// Column names left to right.
  List<String> get _colNames => [
    'X',
    if (_paired) 'Y',
    if (statFrequency) 'FREQ',
  ];

  List<StatItem> get statItems => List.unmodifiable(_stat.items);

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
    if (disabled.contains((key, shift ? 1 : (alpha ? 2 : 0)))) return;
    if (_equation != null && _onEquationKey(key, shift: shift)) return;
    if (_editor && !shift && !alpha && _onEditorKey(key)) return;
    if (_eqnType != null && !shift && !alpha && _onEqnKey(key)) return;
    if (_grid != null && !shift && !alpha && _onGridKey(key)) return;
    if (mode == NaturalMode.table && !shift && !alpha && _onTableKey(key)) {
      return;
    }
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
    _pendingStatements = null;
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
    if (_overwrite && !_mathIO && _ed.cursor.pos < _ed.row.items.length) {
      _ed.row.items.removeAt(_ed.cursor.pos);
    }
    _ed.insertTok(t, paren: paren);
  }

  /// Function with an opening parenthesis (sin(, log(, Abs( in LineIO …).
  void _fn(Tok t) => _tok(t, paren: true);

  void _template(MathTemplate t, {Tok? linear}) {
    if (!_mathIO) {
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
    if (mode == NaturalMode.base && _onBaseKey(key)) return;
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
      case CalcKey.degMinSec when _resultShown && _result != null:
        // °′″ on a result switches decimal ↔ degrees-minutes-seconds.
        final r = _result!;
        _result = r.isSexagesimal ? Value.dec(r.dec) : Value.sexagesimal(r.dec);
        _decimalFirst = r.isSexagesimal; // the decimal, not a fraction
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
        if (_mathIO) {
          _template(MathTemplate.logBase);
        } else {
          _tok(Tok.logBase);
        }
      case CalcKey.integrate:
        if (_mathIO) {
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
        if (_mathIO) {
          _template(MathTemplate.sum);
        } else {
          _tok(Tok.sigma);
        }
      case CalcKey.integrate:
        if (_mathIO) {
          _template(MathTemplate.derivative);
        } else {
          _tok(Tok.derivative);
        }
      case CalcKey.hyp:
        if (_mathIO) {
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
      case CalcKey.d4 when mode == NaturalMode.matrix:
        _menu = _linearMenu(matrix: true);
      case CalcKey.d5 when mode == NaturalMode.vector:
        _menu = _linearMenu(matrix: false);
      case CalcKey.d3 when mode == NaturalMode.base:
        _menu = _logicMenu();
      case CalcKey.d1 when mode == NaturalMode.stat:
        _menu = _statMenu();
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
        if (!_mathIO) _overwrite = !_overwrite;
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
    if (_overwrite && !_mathIO) {
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
      if (_mathIO) _ed.vertical(up: up);
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

  /// Remaining statements of a multi-statement after a Disp stop.
  List<List<Tok>>? _pendingStatements;

  void _execute({bool decimal = false}) {
    final pending = _pendingStatements;
    if (_resultShown && pending != null && pending.isNotEmpty) {
      _runStatement(pending.removeAt(0), decimal: decimal);
      if (pending.isEmpty) _pendingStatements = null;
      return;
    }
    _pendingStatements = null;
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
    // A:B: each = shows the next statement (Disp shown until the last).
    final parts = <List<Tok>>[];
    var from = 0;
    for (var i = 0; i <= tokens.length; i++) {
      if (i == tokens.length || tokens[i] == Tok.colon) {
        parts.add(tokens.sublist(from, i));
        from = i + 1;
      }
    }
    if (parts.length > 1 && _equation == null) {
      _pendingStatements = parts.sublist(1);
      _runStatement(parts.first, decimal: decimal, offset: 0);
      return;
    }
    try {
      final v = _evalStatements(tokens, ctx);
      if (v.isLinear) {
        final name = v.isMatrix ? 'MatAns' : 'VctAns';
        _linear[name] = v;
        _history.add(_History(_ed.root.copy(), v));
        _openGrid(name);
        return;
      }
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

  void _runStatement(List<Tok> tokens, {bool decimal = false, int offset = 0}) {
    try {
      final v = evaluateValue(tokens, _context());
      _setResult(v, record: _pendingStatements == null);
      _decimalFirst = decimal;
    } on CalcError catch (e) {
      _pendingStatements = null;
      _error = _errorText(e.kind);
      _errorCursor = _ed.cursor;
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
          stats: c.stats,
          base: c.base,
          wideBase: c.wideBase,
          linear: c.linear,
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
    exactForms: profile != NaturalProfile.twoLine,
    functionParens: true,
    stats: mode == NaturalMode.stat ? _stat : null,
    base: mode == NaturalMode.base ? _base : null,
    wideBase: true,
    linear: _linear,
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

  void _setFrequency(bool on) {
    if (statFrequency != on) _stat.clear();
    statFrequency = on;
    _col = 0;
  }

  // ------------------------------------------------------------- MATRIX / VECTOR

  static const _matDims = [
    (3, 3),
    (3, 2),
    (3, 1),
    (2, 3),
    (2, 2),
    (2, 1),
    (1, 3),
    (1, 2),
  ];

  /// Matrix? / Vector? then (for Dim) the size menu.
  _Menu _pickVariable({required bool matrix, required bool dim}) {
    final p = matrix ? 'Mat' : 'Vct';
    void open(String name) {
      if (dim) {
        _menu = matrix ? _matDimMenu(name) : _vctDimMenu(name);
      } else if (_linear.containsKey(name)) {
        _openGrid(name);
      } else {
        _error = 'Dimension ERROR';
      }
    }

    final l = _letters;
    return _Menu(
      [
        matrix ? 'Matrix?' : 'Vector?',
        '1:$p${l[0]}  2:$p${l[1]}',
        '3:$p${l[2]}${l.length > 3 ? '  4:$p${l[3]}' : ''}',
      ],
      {for (final (i, x) in l.indexed) i + 1: () => open('$p$x')},
    );
  }

  _Menu _matDimMenu(String name) {
    if (bigLinear) {
      // Rows and columns typed: m? then n? (1-4 each).
      _askDigit('$name  m? (1~4)', 1, 4, (m) {
        _askDigit('$name  n? (1~4)', 1, 4, (n) {
          _dimension(name, Value.matrix(_zeros(m, n)));
        });
      });
      return _Menu(const [''], const {});
    }
    final actions = {
      for (final (i, (r, c)) in _matDims.indexed)
        i + 1: () => _dimension(name, Value.matrix(_zeros(r, c))),
    };
    late _Menu page1, page2;
    page1 = _Menu(
      ['$name(m×n) m×n?', '1:3×3  2:3×2', '3:3×1  4:2×3', '5:2×2  6:2×1'],
      actions,
      next: () => page2,
    );
    page2 = _Menu(
      ['$name(m×n) m×n?', '7:1×3  8:1×2'],
      actions,
      prev: () => page1,
    );
    return page1;
  }

  _Menu _vctDimMenu(String name) => _Menu(
    ['$name(m) m?', '1:3    2:2'],
    {
      1: () => _dimension(name, Value.vector(List.filled(3, Dec.zero))),
      2: () => _dimension(name, Value.vector(List.filled(2, Dec.zero))),
    },
  );

  static List<List<Dec>> _zeros(int r, int c) => [
    for (var i = 0; i < r; i++) List.filled(c, Dec.zero),
  ];

  void _dimension(String name, Value v) {
    _menu = null;
    _linear[name] = v;
    _openGrid(name);
  }

  void _openGrid(String name) {
    _grid = name;
    _gRow = _gCol = 0;
    _clearInput();
  }

  (int, int) _shapeOf(Value v) => v.isMatrix
      ? (v.matrix!.length, v.matrix!.first.length)
      : (1, v.vector!.length);

  Dec _cellOf(Value v, int r, int c) =>
      v.isMatrix ? v.matrix![r][c] : v.vector![c];

  bool get _gridIsAns => _grid == 'MatAns' || _grid == 'VctAns';

  /// Grid editor / Ans screen keys. False: normal handling (typing an
  /// element goes into the input line).
  bool _onGridKey(CalcKey key) {
    final name = _grid!;
    final v = _linear[name]!;
    final (rows, cols) = _shapeOf(v);
    final typing = !_ed.isEmpty;
    if (_gridIsAns) {
      // An operator continues the calculation from MatAns / VctAns.
      final op = switch (key) {
        CalcKey.add => Tok.add,
        CalcKey.subtract => Tok.subtract,
        CalcKey.multiply => Tok.multiply,
        CalcKey.divide => Tok.divide,
        CalcKey.reciprocal when v.isMatrix => Tok.reciprocal,
        CalcKey.square when v.isMatrix => Tok.square,
        _ => null,
      };
      if (op != null) {
        _grid = null;
        _clearInput();
        _ed
          ..insertTok(name == 'MatAns' ? Tok.matAns : Tok.vctAns)
          ..insertTok(op);
        return true;
      }
    }
    switch (key) {
      case CalcKey.equals when typing && !_gridIsAns:
        try {
          final x = _evalStatements(_ed.linearize().tokens, _context());
          if (x.isComplex || x.isLinear) {
            throw const CalcError(CalcErrorKind.math);
          }
          _setCell(name, _gRow, _gCol, x.dec);
        } on CalcError catch (e) {
          _error = _errorText(e.kind);
          _errorCursor = _ed.cursor;
          return true;
        }
        _clearInput();
        if (_gCol < cols - 1) {
          _gCol++;
        } else if (_gRow < rows - 1) {
          _gRow++;
          _gCol = 0;
        }
        return true;
      case CalcKey.up when !typing:
        if (_gRow > 0) _gRow--;
        return true;
      case CalcKey.down when !typing:
        if (_gRow < rows - 1) _gRow++;
        return true;
      case CalcKey.left when !typing:
        if (_gCol > 0) _gCol--;
        return true;
      case CalcKey.right when !typing:
        if (_gCol < cols - 1) _gCol++;
        return true;
      case CalcKey.ac:
        _grid = null;
        _clearInput();
        return true;
      default:
        // Ans screens are read-only; editors accept typing.
        return _gridIsAns && key != CalcKey.mode;
    }
  }

  void _setCell(String name, int r, int c, Dec x) {
    final v = _linear[name]!;
    if (v.isMatrix) {
      final m = [for (final row in v.matrix!) List.of(row)];
      m[r][c] = x;
      _linear[name] = Value.matrix(m);
    } else {
      final vec = List.of(v.vector!);
      vec[c] = x;
      _linear[name] = Value.vector(vec);
    }
  }

  _Menu _linearMenu({required bool matrix}) {
    final p = matrix ? 'Mat' : 'Vct';
    Tok t(String n) => switch ('$p$n') {
      'MatA' => Tok.matA,
      'MatB' => Tok.matB,
      'MatC' => Tok.matC,
      'MatD' => Tok.matD,
      'MatAns' => Tok.matAns,
      'VctA' => Tok.vctA,
      'VctB' => Tok.vctB,
      'VctC' => Tok.vctC,
      'VctD' => Tok.vctD,
      _ => Tok.vctAns,
    };
    void insert(Tok tok) {
      if (_grid != null) {
        _grid = null;
        _clearInput();
      }
      _tok(tok);
    }

    return _Menu(
      [
        '1:Dim    2:Data',
        '3:${p}A   4:${p}B',
        '5:${p}C   6:${p}Ans',
        matrix ? '7:det    8:Trn' : '7:Dot',
      ],
      {
        1: () => _menu = _pickVariable(matrix: matrix, dim: true),
        2: () => _menu = _pickVariable(matrix: matrix, dim: false),
        3: () => insert(t('A')),
        4: () => insert(t('B')),
        5: () => insert(t('C')),
        6: () => insert(t('Ans')),
        if (matrix) ...{
          7: () {
            insert(Tok.det);
            _ed.insertTok(Tok.openParen);
          },
          8: () {
            insert(Tok.trn);
            _ed.insertTok(Tok.openParen);
          },
        } else
          7: () => insert(Tok.dot),
      },
      next: bigLinear
          ? () => _Menu(['9:${p}D'], {9: () => insert(t('D'))})
          : null,
    );
  }

  void _paintGrid(DotBitmap bmp, StringBuffer text) {
    final name = _grid!;
    final v = _linear[name]!;
    final (rows, cols) = _shapeOf(v);
    final short = name.replaceFirst(RegExp('^(Mat|Vct)'), '');
    const rowNumW = 9;
    final colW = (DotScreen.width - rowNumW) ~/ cols;
    bmp.smallText(0, 0, short.length > 2 ? 'Ans' : short);
    for (var c = 0; c < cols; c++) {
      bmp.smallText(rowNumW + c * colW + colW ~/ 2 - 1, 0, '${c + 1}');
    }
    final top = (_gRow - 1).clamp(0, rows);
    final chars = (colW + 1) ~/ 6;
    for (var k = 0; k < 2 && top + k < rows; k++) {
      final r = top + k;
      final y = 6 + k * 8;
      if (v.isMatrix) bmp.smallText(4, y + 1, '${r + 1}');
      for (var c = 0; c < cols; c++) {
        var t = _plainDecimal(Value.dec(_cellOf(v, r, c)));
        if (t.length > chars) t = t.substring(0, chars);
        final x0 = rowNumW + c * colW;
        bmp.text(x0 + colW - textWidth(t) - 1, y, t);
        if (r == _gRow && c == _gCol) {
          bmp.invert(x0, y - 1, x0 + colW - 1, y + 7);
        }
      }
    }
    if (_ed.isEmpty) {
      final t = _plainDecimal(Value.dec(_cellOf(v, _gRow, _gCol)));
      bmp.text(DotScreen.width - textWidth(t) - 1, 24, t);
    } else {
      final layout = MathLayout(_ed.root);
      layout.paint(
        bmp,
        DotScreen.width - layout.width - 2,
        DotScreen.height - layout.height,
      );
    }
    text.write(name);
    for (var r = 0; r < rows; r++) {
      text.write(
        ' | ${[for (var c = 0; c < cols; c++) _plainDecimal(Value.dec(_cellOf(v, r, c)))].join(' ')}',
      );
    }
  }

  // ------------------------------------------------------------- BASE-N

  static const _baseNames = {10: 'Dec', 16: 'Hex', 2: 'Bin', 8: 'Oct'};

  /// DEC / HEX / BIN / OCT and the hex digits A–F on the function keys.
  bool _onBaseKey(CalcKey key) {
    final base = switch (key) {
      CalcKey.square => 10,
      CalcKey.power => 16,
      CalcKey.log => 2,
      CalcKey.ln => 8,
      _ => null,
    };
    if (base != null) {
      // Switches the number system; a shown result is converted.
      _base = base;
      if (_resultShown && _result != null) {
        try {
          baseOutput(_result!.dec, base, wide: true);
        } on CalcError catch (e) {
          _error = _errorText(e.kind);
        }
      }
      return true;
    }
    final hex = switch (key) {
      CalcKey.negative => Tok.hexA,
      CalcKey.degMinSec => Tok.hexB,
      CalcKey.hyp => Tok.hexC,
      CalcKey.sin => Tok.hexD,
      CalcKey.cos => Tok.hexE,
      CalcKey.tan => Tok.hexF,
      _ => null,
    };
    if (hex != null) {
      _tok(hex);
      return true;
    }
    // No fractions, roots, exponents or decimal results in BASE-N.
    return const {
      CalcKey.fraction,
      CalcKey.sqrt,
      CalcKey.exp,
      CalcKey.dot,
      CalcKey.sd,
      CalcKey.logBase,
      CalcKey.integrate,
      CalcKey.reciprocal,
      CalcKey.eng,
      CalcKey.degMinSec,
    }.contains(key);
  }

  _Menu _logicMenu() => _Menu(
    const ['1:and    2:or', '3:xor    4:xnor', '5:Not(   6:Neg('],
    {
      1: () => _tok(Tok.logicAnd),
      2: () => _tok(Tok.logicOr),
      3: () => _tok(Tok.logicXor),
      4: () => _tok(Tok.logicXnor),
      5: () => _fn(Tok.logicNot),
      6: () => _fn(Tok.logicNeg),
    },
    next: _prefixMenu,
  );

  _Menu _prefixMenu() => _Menu(
    const ['1:d      2:h', '3:b      4:o'],
    {
      1: () => _tok(Tok.baseD),
      2: () => _tok(Tok.baseH),
      3: () => _tok(Tok.baseB),
      4: () => _tok(Tok.baseO),
    },
    prev: _logicMenu,
  );

  /// BASE-N result: padded to the register width (16 binary digits …).
  MathRow _baseRow(Value v) {
    var t = baseOutput(v.dec, _base, wide: true);
    final width = {2: 16, 8: 11, 16: 8}[_base];
    if (width != null) t = t.toUpperCase().padLeft(width, '0');
    return MathRow([
      for (final c in t.split(''))
        TokItem(switch (c) {
          '-' => Tok.negative,
          'A' => Tok.hexA,
          'B' => Tok.hexB,
          'C' => Tok.hexC,
          'D' => Tok.hexD,
          'E' => Tok.hexE,
          'F' => Tok.hexF,
          _ => Tok.digits[int.parse(c)],
        }),
    ]);
  }

  // ------------------------------------------------------------- TABLE

  static const _tableLabels = ['Start?', 'End?', 'Step?'];
  static const maxTableRows = 30;

  /// TABLE keys: = on f(X) starts the prompts; prompts and the table
  /// screen take their own keys. False: normal editing of f(X).
  bool _onTableKey(CalcKey key) {
    if (_table != null) {
      switch (key) {
        case CalcKey.up:
          if (_tRow > 0) _tRow--;
        case CalcKey.down:
          if (_tRow < _table!.length - 1) _tRow++;
        case CalcKey.left:
          _tCol = 0;
        case CalcKey.right:
          _tCol = 1;
        case CalcKey.ac:
          // Back to f(X), kept for editing.
          _table = null;
          _ed.load(_tableFn ?? MathRow());
        default:
          break;
      }
      return true;
    }
    final p = _tablePrompt;
    if (p != null) {
      final d = key.digit;
      if (d != null) {
        _tableTyped += '$d';
        return true;
      }
      switch (key) {
        case CalcKey.dot:
          _tableTyped += '.';
        case CalcKey.negative:
          _tableTyped += '-';
        case CalcKey.del:
          if (_tableTyped.isNotEmpty) {
            _tableTyped = _tableTyped.substring(0, _tableTyped.length - 1);
          }
        case CalcKey.ac:
          _tablePrompt = null;
          _tableTyped = '';
        case CalcKey.equals:
          if (_tableTyped.isNotEmpty) {
            try {
              _tableRange[p] = evaluateValue([
                for (final c in _tableTyped.split(''))
                  switch (c) {
                    '.' => Tok.point,
                    '-' => Tok.negative,
                    _ => Tok.digits[int.parse(c)],
                  },
              ], _context()).dec;
            } on CalcError catch (e) {
              _tablePrompt = null;
              _error = _errorText(e.kind);
              return true;
            }
          }
          _tableTyped = '';
          if (p < 2) {
            _tablePrompt = p + 1;
          } else {
            _tablePrompt = null;
            _buildTable();
          }
        default:
          break;
      }
      return true;
    }
    if (key == CalcKey.equals && !_ed.isEmpty) {
      _tableFn = _ed.root.copy();
      _tablePrompt = 0;
      _tableTyped = '';
      return true;
    }
    return false;
  }

  void _buildTable() {
    final [start, end, step] = _tableRange;
    if (end < start || step <= Dec.zero) {
      _error = 'Math ERROR';
      return;
    }
    final count = ((end - start) / step).roundSignificant(12).toIntFloor() + 1;
    if (count > maxTableRows) {
      _error = 'Insufficient MEM';
      return;
    }
    final tokens = MathEditor(_tableFn!.copy()).linearize().tokens;
    final rows = <(Dec, Value?)>[];
    for (var k = 0; k < count; k++) {
      final x = start + step * Dec.fromInt(k);
      _vars['X'] = Value.dec(x);
      Value? fx;
      try {
        fx = evaluateValue(tokens, _context());
      } on CalcError {
        fx = null; // shown as ERROR in that row
      }
      rows.add((x, fx));
    }
    _table = rows;
    _tRow = 0;
    _tCol = 1;
  }

  void _paintTable(DotBitmap bmp, StringBuffer text) {
    final p = _tablePrompt;
    if (p != null) {
      bmp.text(0, 0, _tableLabels[p]);
      final shown = _tableTyped.isNotEmpty
          ? _tableTyped
          : _plainDecimal(Value.dec(_tableRange[p]));
      bmp.text(DotScreen.width - textWidth(shown) - 1, 24, shown);
      text.write('${_tableLabels[p]} $shown');
      return;
    }
    final rows = _table!;
    const rowNumW = 9;
    const colW = (DotScreen.width - rowNumW) ~/ 2;
    bmp
      ..smallText(rowNumW + colW ~/ 2 - 1, 0, 'X')
      ..smallText(rowNumW + colW + colW ~/ 2 - 7, 0, 'F(X)');
    String cell((Dec, Value?) r, int c) {
      if (c == 0) return _plainDecimal(Value.dec(r.$1));
      return r.$2 == null ? 'ERROR' : _plainDecimal(r.$2!);
    }

    final top = (_tRow - 1).clamp(0, rows.length);
    const chars = (colW + 1) ~/ 6;
    for (var k = 0; k < 2 && top + k < rows.length; k++) {
      final r = top + k;
      final y = 6 + k * 8;
      bmp.smallText(0, y + 1, '${r + 1}');
      for (var c = 0; c < 2; c++) {
        var t = cell(rows[r], c);
        if (t.length > chars) t = t.substring(0, chars);
        final x0 = rowNumW + c * colW;
        bmp.text(x0 + colW - textWidth(t) - 1, y, t);
        if (r == _tRow && c == _tCol) {
          bmp.invert(x0, y - 1, x0 + colW - 1, y + 7);
        }
      }
    }
    final full = cell(rows[_tRow], _tCol);
    bmp.text(DotScreen.width - textWidth(full) - 1, 24, full);
    text.write('TABLE');
    for (final r in rows) {
      text.write(' | ${cell(r, 0)} ${cell(r, 1)}');
    }
  }

  // ------------------------------------------------------------- EQN

  _Menu _eqnTypeMenu() {
    final page1 = _Menu(
      const [
        '1:anX+bnY=cn',
        '2:anX+bnY+cnZ=dn',
        '3:aX²+bX+c=0',
        '4:aX³+bX²+cX+d=0',
      ],
      {
        for (final t in EqnType.values)
          if (t != EqnType.lin4 || bigLinear) t.index + 1: () => _setEqnType(t),
      },
      next: bigLinear
          ? () => _Menu(
              const ['5:4 unknowns'],
              {5: () => _setEqnType(EqnType.lin4)},
              prev: _eqnTypeMenu,
            )
          : null,
    );
    return page1;
  }

  (int, int) get _eqnShape => switch (_eqnType!) {
    EqnType.lin2 => (2, 3),
    EqnType.lin3 => (3, 4),
    EqnType.lin4 => (4, 5),
    EqnType.quad => (1, 3),
    EqnType.cubic => (1, 4),
  };

  void _setEqnType(EqnType t) {
    _eqnType = t;
    final (rows, cols) = _eqnShape;
    _coef = [
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < cols; c++) Value.zero],
    ];
    _eRow = _eCol = 0;
    _solutions = null;
    _clearInput();
  }

  /// Coefficient Editor and solution screens. False: normal handling
  /// (typing a coefficient goes into the input line).
  bool _onEqnKey(CalcKey key) {
    final sols = _solutions;
    if (sols != null) {
      switch (key) {
        case CalcKey.equals || CalcKey.down:
          if (_solIndex < sols.length - 1) {
            _solIndex++;
          } else if (key == CalcKey.equals) {
            _solutions = null;
          }
        case CalcKey.up:
          if (_solIndex > 0) _solIndex--;
        case CalcKey.ac:
          _solutions = null;
        case CalcKey.mode:
          return false;
        default:
          break;
      }
      return true;
    }
    final (rows, cols) = _eqnShape;
    final typing = !_ed.isEmpty;
    switch (key) {
      case CalcKey.equals:
        if (typing) {
          _commitCoefficient();
        } else {
          _solveEqn();
        }
        return true;
      case CalcKey.ac:
        for (final row in _coef) {
          row.fillRange(0, row.length, Value.zero);
        }
        _clearInput();
        return true;
      case CalcKey.up when !typing:
        if (_eRow > 0) _eRow--;
        return true;
      case CalcKey.down when !typing:
        if (_eRow < rows - 1) _eRow++;
        return true;
      case CalcKey.left when !typing:
        if (_eCol > 0) _eCol--;
        return true;
      case CalcKey.right when !typing:
        if (_eCol < cols - 1) _eCol++;
        return true;
      default:
        return false;
    }
  }

  void _commitCoefficient() {
    try {
      final v = _evalStatements(_ed.linearize().tokens, _context());
      if (v.isComplex || v.isLinear) throw const CalcError(CalcErrorKind.math);
      _coef[_eRow][_eCol] = v;
    } on CalcError catch (e) {
      _error = _errorText(e.kind);
      _errorCursor = _ed.cursor;
      return;
    }
    _clearInput();
    final (rows, cols) = _eqnShape;
    if (_eCol < cols - 1) {
      _eCol++;
    } else if (_eRow < rows - 1) {
      _eRow++;
      _eCol = 0;
    }
  }

  void _solveEqn() {
    try {
      final t = _eqnType!;
      final List<Value> sols;
      if (t == EqnType.lin2 || t == EqnType.lin3 || t == EqnType.lin4) {
        sols = solveLinear([
          for (final row in _coef) [for (final v in row) v.dec],
        ]).map(_cleanLinear).toList();
      } else if (t == EqnType.quad) {
        sols = _exactQuadratic(_coef[0][0], _coef[0][1], _coef[0][2]);
      } else {
        final r = solvePolynomial([for (final v in _coef[0]) v.dec]);
        // Root order of the textbook models (behaviour note #81).
        sols = r.length == 3 && !r[1].isComplex ? [r[1], r[0], r[2]] : r;
      }
      _solutions = sols;
      _solIndex = 0;
    } on CalcError catch (e) {
      _error = _errorText(e.kind);
      _errorCursor = null;
    }
  }

  /// Simultaneous-equation solutions: exact fractions where they are
  /// simple, never √ forms.
  Value _cleanLinear(Value v) {
    final f = Frac.approximate(v.dec);
    return f != null && !f.isInteger ? Value.frac(f) : v;
  }

  /// Quadratic roots kept exact when the coefficients are (fractions,
  /// √ forms): x = (−b ± √D) / 2a.
  List<Value> _exactQuadratic(Value a, Value b, Value c) {
    if (a.dec.isZero) throw const CalcError(CalcErrorKind.math);
    final four = Value.dec(Dec.fromInt(4));
    final two = Value.dec(Dec.fromInt(2));
    final d = b * b - four * a * c;
    final twoA = two * a;
    final dExact = d.frac ?? (d.dec.isInteger ? Frac.fromDec(d.dec) : null);
    final nearZero =
        d.dec.abs() <=
        (b.dec * b.dec).abs() * Dec.parse('1e-13') + Dec.parse('1e-90');
    if (dExact != null || nearZero) {
      final mid = (-b) / twoA;
      if (nearZero || dExact!.n == BigInt.zero) return [mid];
      final root = Surd.sqrtOf(dExact.isNegative ? -dExact : dExact);
      if (root != null) {
        final r = Value.fromSurd(root) / twoA;
        if (!dExact.isNegative) return [mid + r, mid - r];
        return [
          Value.complex(mid.dec, r.dec.abs()),
          Value.complex(mid.dec, -r.dec.abs()),
        ];
      }
    }
    return solvePolynomial([a.dec, b.dec, c.dec]);
  }

  void _paintEqn(DotBitmap bmp, StringBuffer text) {
    final sols = _solutions;
    if (sols != null) {
      final linear =
          _eqnType == EqnType.lin2 ||
          _eqnType == EqnType.lin3 ||
          _eqnType == EqnType.lin4;
      final name = linear
          ? const ['X', 'Y', 'Z', 'T'][_solIndex]
          : (sols.length == 1 ? 'X' : 'X${_solIndex + 1}');
      bmp.text(0, 0, '$name=');
      final row = _rowFor(sols[_solIndex], surd: !linear);
      final layout = MathLayout(row);
      layout.paint(
        bmp,
        DotScreen.width - layout.width - 1,
        DotScreen.height - layout.height,
      );
      text.write('$name= $row');
      return;
    }
    final (rows, cols) = _eqnShape;
    const letters = ['a', 'b', 'c', 'd', 'e'];
    const rowNumW = 7;
    final colW = (DotScreen.width - rowNumW) ~/ cols;
    for (var c = 0; c < cols; c++) {
      bmp.smallText(rowNumW + c * colW + colW ~/ 2 - 1, 0, letters[c]);
    }
    final top = (_eRow - 1).clamp(0, rows);
    final chars = (colW + 1) ~/ 6;
    for (var k = 0; k < 2 && top + k < rows; k++) {
      final r = top + k;
      final y = 6 + k * 8;
      if (rows > 1) bmp.smallText(0, y + 1, '${r + 1}');
      for (var c = 0; c < cols; c++) {
        var t = _plainDecimal(_coef[r][c]);
        if (t.length > chars) t = t.substring(0, chars);
        final x0 = rowNumW + c * colW;
        bmp.text(x0 + colW - textWidth(t) - 1, y, t);
        if (r == _eRow && c == _eCol) {
          bmp.invert(x0, y - 1, x0 + colW - 1, y + 7);
        }
      }
    }
    if (_ed.isEmpty) {
      final t = _plainDecimal(_coef[_eRow][_eCol]);
      bmp.text(DotScreen.width - textWidth(t) - 1, 24, t);
    } else {
      final layout = MathLayout(_ed.root);
      final c = layout.paint(
        bmp,
        DotScreen.width - layout.width - 2,
        DotScreen.height - layout.height,
        cursor: _ed.cursor,
      );
      _eqnCursor = c;
    }
    text.write('EQN ${_eqnType!.name}');
    for (var r = 0; r < rows; r++) {
      text.write(
        ' | ${[for (final v in _coef[r]) _plainDecimal(v)].join(' ')}',
      );
    }
    text.write(' | cell ${_eRow + 1},${letters[_eCol]} ${_ed.root}');
  }

  CursorRect? _eqnCursor;

  /// A value in its display form (results, solutions).
  MathRow _rowFor(Value v, {bool surd = true}) {
    if (v.isComplex) return _complexRow(v);
    final exact = _mathIO && mathOutput;
    final form = exact ? exactFormOf(v, surd: surd) : null;
    return switch (form) {
      FractionForm(:final value) => _fractionRow(
        value,
        improper,
        linear: false,
      ),
      SurdForm(:final value) => _surdRow(value),
      PiForm(:final coefficient) => _piRow(coefficient),
      null => _decimalRow(
        formatValue(
          v,
          DisplaySettings(format: format, leadingZeroCounts: false),
          view: ResultView.decimal,
        ),
      ),
    };
  }

  // ------------------------------------------------------------- STAT

  static const _statTypeLines = [
    '1:1-VAR  2:A+BX',
    '3:_+CX²  4:ln X',
    '5:e^X    6:A·B^X',
    '7:A·X^B  8:1/X',
  ];

  _Menu _statTypeMenu() => _Menu(_statTypeLines, {
    for (final t in StatType.values) t.index + 1: () => _setStatType(t),
  });

  void _setStatType(StatType t) {
    final wasPaired = _paired;
    statType = t;
    if (wasPaired != _paired) _stat.clear();
    _stat.type = switch (t) {
      StatType.oneVar || StatType.lin => RegressionType.lin,
      StatType.quad => RegressionType.quad,
      StatType.log => RegressionType.log,
      StatType.eExp => RegressionType.exp,
      StatType.abExp => RegressionType.abExp,
      StatType.pwr => RegressionType.pwr,
      StatType.inv => RegressionType.inv,
    };
    _openEditor();
  }

  void _openEditor() {
    _editor = true;
    _resultShown = false;
    _row = _stat.items.length.clamp(0, _maxRows - 1);
    _col = 0;
    _cell = '';
    _top = (_row - 1).clamp(0, 1 << 20);
  }

  /// Keys in the Stat Editor; false lets other handling take the key.
  bool _onEditorKey(CalcKey key) {
    final d = key.digit;
    if (d != null) {
      _cell += '$d';
      return true;
    }
    switch (key) {
      case CalcKey.dot:
        _cell += '.';
      case CalcKey.negative:
        _cell += '-';
      case CalcKey.exp:
        _cell += 'E';
      case CalcKey.del:
        if (_cell.isNotEmpty) {
          _cell = _cell.substring(0, _cell.length - 1);
        } else if (_row < _stat.items.length) {
          _stat.items.removeAt(_row);
          _row = _row.clamp(0, _stat.items.length);
        }
      case CalcKey.equals:
        _commitCell();
      case CalcKey.up:
        _cell = '';
        if (_row > 0) _row--;
      case CalcKey.down:
        _cell = '';
        if (_row < _stat.items.length && _row < _maxRows - 1) _row++;
      case CalcKey.left:
        _cell = '';
        if (_col > 0) _col--;
      case CalcKey.right:
        _cell = '';
        if (_col < _cols - 1) _col++;
      case CalcKey.ac:
        _editor = false;
        _clearInput();
      default:
        return false;
    }
    if (_row < _top) _top = _row;
    if (_row > _top + 2) _top = _row - 2;
    return true;
  }

  void _commitCell() {
    if (_cell.isEmpty) {
      if (_row < _stat.items.length) _row++;
      return;
    }
    final toks = <Tok>[
      for (final c in _cell.split(''))
        switch (c) {
          '.' => Tok.point,
          '-' => Tok.negative,
          'E' => Tok.exp,
          _ => Tok.digits[int.parse(c)],
        },
    ];
    final Dec v;
    try {
      v = evaluateValue(toks, _context()).dec;
    } on CalcError catch (e) {
      _cell = '';
      _error = _errorText(e.kind);
      _errorCursor = null;
      return;
    }
    _cell = '';
    if (_row >= _stat.items.length) {
      if (_stat.items.length >= _maxRows) return;
      _stat.add(StatItem(Dec.zero, y: _paired ? Dec.zero : null));
    }
    final item = _stat.items[_row];
    final name = _colNames[_col];
    _stat.items[_row] = switch (name) {
      'X' => item.copyWith(x: v),
      'Y' => item.copyWith(y: v),
      _ => item.copyWith(freq: v),
    };
    if (_row < _maxRows - 1) _row++;
  }

  _Menu _statMenu() {
    final edit = _editor;
    final last = _paired ? 'Reg' : 'Distr';
    final lines = edit
        ? [
            '1:Type   2:Data',
            '3:Edit   4:Sum',
            '5:Var    6:${last.padRight(6)}',
            '7:MinMax',
          ]
        : [
            '1:Type   2:Data',
            '3:Sum    4:Var',
            '5:${last.padRight(6)} 6:MinMax',
          ];
    final o = edit ? 1 : 0;
    return _Menu(lines, {
      1: () => _menu = _statTypeMenu(),
      2: _openEditor,
      if (edit)
        3: () => _menu = _Menu(
          const ['1:Ins    2:Del-A'],
          {
            1: () {
              _stat.items.insert(
                _row.clamp(0, _stat.items.length),
                StatItem(Dec.zero, y: _paired ? Dec.zero : null),
              );
            },
            2: () {
              _stat.clear();
              _row = _top = 0;
            },
          },
        ),
      3 + o: () => _menu = _sumMenu(),
      4 + o: () => _menu = _varMenu(),
      5 + o: () => _menu = _paired ? _regMenu() : _distrMenu(),
      6 + o: () => _menu = _minMaxMenu(),
    });
  }

  /// Puts a statistics token into the calculation (leaving the editor).
  void Function() _statTok(Tok t) => () {
    if (_editor) {
      _editor = false;
      _clearInput();
    }
    _tok(t);
  };

  _Menu _pick(List<String> lines, List<Tok> toks) =>
      _Menu(lines, {for (final (i, t) in toks.indexed) i + 1: _statTok(t)});

  _Menu _sumMenu() => _paired
      ? _pick(
          const [
            '1:Σx²   2:Σx',
            '3:Σy²   4:Σy',
            '5:Σxy   6:Σx³',
            '7:Σx²y  8:Σx⁴',
          ],
          const [
            Tok.statSumX2,
            Tok.statSumX,
            Tok.statSumY2,
            Tok.statSumY,
            Tok.statSumXY,
            Tok.statSumX3,
            Tok.statSumX2Y,
            Tok.statSumX4,
          ],
        )
      : _pick(const ['1:Σx²   2:Σx'], const [Tok.statSumX2, Tok.statSumX]);

  _Menu _varMenu() => _pick(
    [
      '1:n      2:\uE000',
      '3:xσn    4:xσn-1',
      if (_paired) ...['5:\uE001      6:yσn', '7:yσn-1'],
    ],
    [
      Tok.statN,
      Tok.statMeanX,
      Tok.statSigmaX,
      Tok.statSampleX,
      if (_paired) ...[Tok.statMeanY, Tok.statSigmaY, Tok.statSampleY],
    ],
  );

  _Menu _regMenu() => statType == StatType.quad
      ? _pick(
          const [
            '1:A      2:B',
            '3:C      4:\uE0021',
            '5:\uE0022     6:\uE003',
          ],
          const [Tok.regA, Tok.regB, Tok.regC, Tok.estX1, Tok.estX2, Tok.estY],
        )
      : _pick(
          const ['1:A      2:B', '3:r      4:\uE002', '5:\uE003'],
          const [Tok.regA, Tok.regB, Tok.regR, Tok.estX, Tok.estY],
        );

  _Menu _distrMenu() => _pick(
    const ['1:P(     2:Q(', '3:R(     4:▶t'],
    const [Tok.distP, Tok.distQ, Tok.distR, Tok.toT],
  );

  _Menu _minMaxMenu() => _paired
      ? _pick(
          const ['1:minX   2:maxX', '3:minY   4:maxY'],
          const [Tok.statMinX, Tok.statMaxX, Tok.statMinY, Tok.statMaxY],
        )
      : _pick(const ['1:minX   2:maxX'], const [Tok.statMinX, Tok.statMaxX]);

  /// Stat Editor screen: small header, two data rows, the cell value below.
  void _paintEditor(DotBitmap bmp, StringBuffer text) {
    const rowNumW = 9;
    final colW = (DotScreen.width - rowNumW) ~/ _cols;
    final names = _colNames;
    for (var c = 0; c < _cols; c++) {
      final n = listNames ? 'L${c + 1}' : names[c];
      final x = rowNumW + c * colW + (colW - smallTextWidth(n)) ~/ 2;
      bmp.smallText(x, 0, n);
    }
    final chars = (colW + 1) ~/ 6;
    String cellText(int r, int c) {
      if (r >= _stat.items.length) return '';
      final it = _stat.items[r];
      final v = switch (names[c]) {
        'X' => it.x,
        'Y' => it.y ?? Dec.zero,
        _ => it.freq,
      };
      final t = _plainDecimal(Value.dec(v));
      return t.length > chars ? t.substring(0, chars) : t;
    }

    // Two rows fit above the input line; keep the cursor row in view.
    if (_row < _top) _top = _row;
    if (_row > _top + 1) _top = _row - 1;
    for (var k = 0; k < 3; k++) {
      final r = _top + k;
      if (r >= _maxRows) break;
      final y = 6 + k * 8;
      if (k == 2) break; // third row would overlap the input line
      bmp.smallText(0, y + 1, '${r + 1}');
      for (var c = 0; c < _cols; c++) {
        final t = cellText(r, c);
        final x0 = rowNumW + c * colW;
        bmp.text(x0 + colW - textWidth(t) - 1, y, t);
        if (r == _row && c == _col) bmp.invert(x0, y - 1, x0 + colW - 1, y + 7);
      }
    }
    final current = _cell.isNotEmpty
        ? _cell.replaceAll('E', '×10^')
        : (_row < _stat.items.length ? cellText(_row, _col) : '');
    bmp.text(DotScreen.width - textWidth(current) - 1, 24, current);
    text.write('STAT ${names.join(' ')}');
    for (var r = 0; r < _stat.items.length; r++) {
      text.write(
        ' | ${r + 1}: ${[for (var c = 0; c < _cols; c++) cellText(r, c)].join(' ')}',
      );
    }
    text.write(
      ' | cell ${_row + 1},${names[_col]} ${_cell.isEmpty ? '' : _cell}',
    );
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
    final mathOut = _mathIO && mathOutput;
    // Exact first on MathO / LineO; decimal first on LineIO and after SHIFT =.
    final exactFirst = _mathIO && !_decimalFirst;
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
    if (menuCursor && _pendingConfirm == null && m.lines.first != 'CONTRAST') {
      final items = _items(m);
      if (items.isNotEmpty) {
        if (!identical(_menuSeen, m)) {
          _menuSeen = m;
          _menuIndex = 0;
        }
        switch (key) {
          case CalcKey.right:
            _menuIndex = (_menuIndex + 1) % items.length;
            return;
          case CalcKey.left:
            _menuIndex = (_menuIndex - 1 + items.length) % items.length;
            return;
          case CalcKey.equals:
            final action = m.actions[items[_menuIndex].$1];
            if (action != null) {
              _menu = null;
              action();
            }
            return;
          default:
            break;
        }
      }
    }
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

  static const _modeNames = {
    NaturalMode.comp: 'COMP',
    NaturalMode.cmplx: 'CMPLX',
    NaturalMode.stat: 'STAT',
    NaturalMode.base: 'BASE-N',
    NaturalMode.eqn: 'EQN',
    NaturalMode.matrix: 'MATRIX',
    NaturalMode.table: 'TABLE',
    NaturalMode.vector: 'VECTOR',
  };

  /// MODE list of this model's modes, numbered in order, two per line.
  _Menu _modeMenu() {
    final list = [
      for (final m in NaturalMode.values)
        if (modes.contains(m)) m,
    ];
    final lines = <String>[
      for (var i = 0; i < list.length; i += 2)
        i + 1 < list.length
            ? '${'${i + 1}:${_modeNames[list[i]]}'.padRight(8)}'
                  '${i + 2}:${_modeNames[list[i + 1]]}'
            : '${i + 1}:${_modeNames[list[i]]}',
    ];
    return _Menu(lines, {
      for (final (i, m) in list.indexed) i + 1: () => _setMode(m),
    });
  }

  void _setMode(NaturalMode m) {
    if (mode == NaturalMode.stat && m != NaturalMode.stat) {
      _stat.clear(); // Leaving STAT deletes its data.
    }
    mode = m;
    _equation = null;
    _editor = false;
    _eqnType = null;
    _solutions = null;
    _table = null;
    _tablePrompt = null;
    _base = 10;
    _grid = null;
    if (m == NaturalMode.stat) {
      _history.clear();
      _clearInput();
      _menu = _statTypeMenu();
      return;
    }
    if (m == NaturalMode.eqn) {
      _history.clear();
      _clearInput();
      _menu = _eqnTypeMenu();
      return;
    }
    if (m == NaturalMode.matrix || m == NaturalMode.vector) {
      _grid = null;
      _history.clear();
      _clearInput();
      _menu = _pickVariable(matrix: m == NaturalMode.matrix, dim: true);
      return;
    }
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
        {1: () => _setFrequency(true), 2: () => _setFrequency(false)},
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
    _linear.clear();
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
      if (_mathIO) Indicator.math,
      if (mode == NaturalMode.cmplx) Indicator.cmplx,
      if (mode == NaturalMode.stat) Indicator.stat,
      if (_resultShown && (_pendingStatements?.isNotEmpty ?? false))
        Indicator.disp,
      if (mode == NaturalMode.matrix) Indicator.mat,
      if (mode == NaturalMode.vector) Indicator.vct,
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
    } else if (mode == NaturalMode.table &&
        _menu == null &&
        (_tablePrompt != null || _table != null)) {
      _paintTable(bmp, text);
    } else if (_grid != null && _menu == null) {
      _paintGrid(bmp, text);
    } else if (_eqnType != null && _menu == null) {
      _eqnCursor = null;
      _paintEqn(bmp, text);
      cursor = _eqnCursor;
    } else if (_editor && _menu == null) {
      _paintEditor(bmp, text);
    } else if (_menu != null) {
      final m = _menu!;
      final items = menuCursor ? _items(m) : const <(int, String)>[];
      if (items.isEmpty) {
        for (var i = 0; i < m.lines.length && i < 4; i++) {
          bmp.text(0, i * 8, m.lines[i]);
        }
      } else {
        if (!identical(_menuSeen, m)) {
          _menuSeen = m;
          _menuIndex = 0;
        }
        // Names across the line, wrapping; the chosen one highlighted.
        final title = m.lines.first.contains(':') ? null : m.lines.first;
        var x = 0, y = 0;
        if (title != null) {
          bmp.text(0, 0, title);
          y = 8;
        }
        for (final (i, (_, label)) in items.indexed) {
          final w = textWidth(label);
          if (x > 0 && x + w > DotScreen.width) {
            x = 0;
            y += 8;
          }
          if (y > 24) break;
          bmp.text(x + 1, y, label);
          if (i == _menuIndex) {
            bmp.invert(x, y == 0 ? 0 : y - 1, x + w + 1, y + 7);
          }
          x += w + 8;
        }
      }
      if (m.next != null) ind.add(Indicator.scrollDown);
      if (m.prev != null) ind.add(Indicator.scrollUp);
      text.write(m.lines.join(' | '));
    } else {
      cursor = switch (profile) {
        NaturalProfile.multiLine => _paintHistory(bmp, text),
        NaturalProfile.twoLine => _paintTwoLine(bmp, text),
        NaturalProfile.textbook => _paintCalculation(bmp, text),
      };
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
    if (mode == NaturalMode.base) {
      final name = _baseNames[_base]!;
      final x = DotScreen.width - smallTextWidth(name);
      for (var y = 0; y < 6; y++) {
        for (var i = x - 2; i < DotScreen.width; i++) {
          bmp.set(i, y, false);
        }
      }
      bmp.smallText(x, 0, name);
      text.write(' [$name]');
    }
    return editing ? cursor : null;
  }

  static const _twoLineSymbols = {
    Tok.divide: '/',
    Tok.multiply: '*',
    Tok.fracSep: '⌟',
  };

  /// Two-line screen: scrolling entry line, tall result line.
  CursorRect? _paintTwoLine(DotBitmap bmp, StringBuffer text) {
    final layout = MathLayout(_ed.root, symbols: _twoLineSymbols);
    final editing = !_resultShown;
    final probe = DotBitmap(layout.width + 8, layout.height + 1);
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
      1,
      cursor: editing ? _ed.cursor : null,
    );
    if (editing && _ed.isEmpty) cursor = const CursorRect(1, 1, 7);
    text.write(_ed.root.toString());
    if (_resultShown && _result != null) {
      final (mantissa, exponent) = _twoLineResult(_result!);
      var right = DotScreen.width - 1;
      if (exponent != null) {
        // ×10 and the exponent sit raised at the right edge.
        final ew = textWidth(exponent);
        bmp.text(DotScreen.width - ew - 1, 12, exponent);
        final xw = smallTextWidth('×10');
        bmp.smallText(DotScreen.width - ew - xw - 3, 20, '×10');
        right = DotScreen.width - ew - xw - 6;
      }
      bmp.tallText(right - textWidth(mantissa), 20, mantissa);
      text.write(' = $mantissa${exponent == null ? '' : ' E$exponent'}');
    }
    return editing ? cursor : null;
  }

  /// Result text for the two-line display: fractions when the calculation
  /// was made of fractions (◄► / S⇔D toggles), else the decimal with its
  /// point.
  (String, String?) _twoLineResult(Value v) {
    if (v.isComplex || v.isLinear) return ('ERROR', null);
    if (mode == NaturalMode.base) return (_baseRow(v).toString(), null);
    Frac? f = v.frac;
    if (_alternate) f = f == null ? Frac.approximate(v.dec) : null;
    if (f != null && !f.isInteger && _engExponent == null) {
      final n = f.n.abs(), d = f.d;
      final sign = f.isNegative ? '-' : '';
      if (improper != _flipMixed || n < d) return ('$sign$n/$d', null);
      return ('$sign${n ~/ d}u${n % d}/$d', null);
    }
    final fmt = v.isSexagesimal
        ? formatValue(
            v,
            DisplaySettings(format: format),
            view: ResultView.sexagesimal,
          )
        : formatValue(
            v,
            DisplaySettings(format: format, decimalComma: decimalComma),
            view: ResultView.decimal,
            engExponent: _engExponent,
          );
    var m = fmt.mantissa;
    if (decimalComma) m = m.replaceAll('.', ',');
    return (m.replaceAll('°', '°'), fmt.exponent);
  }

  /// Four-line screen: the current line at the bottom, earlier entries and
  /// results above it (newest lowest), like a paper roll.
  CursorRect? _paintHistory(DotBitmap bmp, StringBuffer text) {
    // (input, result) pairs, oldest first; the current one last.
    final entries = <(MathRow, MathRow?)>[];
    final keep = _resultShown ? _history.length - 1 : _history.length;
    for (var i = 0; i < keep; i++) {
      final h = _history[i];
      entries.add((h.input, _rowFor(h.result)));
    }
    final editing = !_resultShown;
    if (_resultShown && _result != null) {
      entries.add((_ed.root, _currentResultRow()));
    } else {
      entries.add((_ed.root, null));
    }
    var bottom = DotScreen.height; // next free row from the bottom
    CursorRect? cursor;
    for (final (i, (input, result)) in entries.reversed.indexed) {
      if (bottom <= 0) break;
      final inLayout = MathLayout(input);
      final current = i == 0;
      if (result != null) {
        final r = MathLayout(result);
        final sameLine =
            inLayout.width + r.width + 6 <= DotScreen.width &&
            inLayout.height <= 8 &&
            r.height <= 8;
        if (sameLine) {
          final h = inLayout.height > r.height ? inLayout.height : r.height;
          final top = bottom - h;
          if (top < 0 && !current) break; // only whole entries are shown
          inLayout.paint(bmp, 1, top + h - inLayout.height);
          r.paint(bmp, DotScreen.width - r.width - 1, top + h - r.height);
          bottom = top - 1;
          continue;
        }
        if (!current && bottom - r.height < 0) break;
        r.paint(bmp, DotScreen.width - r.width - 1, bottom - r.height);
        bottom -= r.height + 1;
      }
      final top = bottom - inLayout.height;
      if (top < 0 && !current) break;
      final c = inLayout.paint(
        bmp,
        1,
        top,
        cursor: current && editing ? _ed.cursor : null,
      );
      if (current && editing) cursor = c;
      bottom = top - 1;
    }
    if (editing && _ed.isEmpty) {
      cursor = const CursorRect(1, DotScreen.height - 7, 7);
    }
    text.write(_ed.root.toString());
    if (_resultShown && _result != null) {
      text.write(' = ${_currentResultRow()}');
    }
    // Entries left above the screen are marked like the device does.
    return cursor;
  }

  /// The shown result honouring S⇔D, SHIFT = and ENG (as on the result line).
  MathRow _currentResultRow() {
    final probe = DotBitmap(DotScreen.width, DotScreen.height);
    final sb = StringBuffer();
    _lastResultRow = null;
    _paintResult(probe, sb);
    return _lastResultRow!;
  }

  MathRow? _lastResultRow;

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
    if (mode == NaturalMode.base) {
      try {
        row = _baseRow(r);
      } on CalcError {
        row = MathRow([TokItem(Tok.negative)]);
      }
    } else if (r.isComplex) {
      row = _complexRow(r);
    } else if (form is FractionForm) {
      final improperView = improper != _flipMixed;
      row = _fractionRow(
        form.value,
        improperView,
        linear: !(_mathIO && mathOutput),
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
    _lastResultRow = row;
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
    final exact = _mathIO && mathOutput && !_alternate && !_decimalFirst;
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
  List<Tok>? get graphTokens =>
      mode == NaturalMode.comp &&
          _grid == null &&
          _eqnType == null &&
          !_ed.isEmpty
      ? graphableTokens(_ed.linearize().tokens)
      : null;

  @override
  AngleUnit get angleUnit => angle;

  @override
  GraphSpec? get graphSpec {
    if (mode == NaturalMode.comp) return functionSpec(graphTokens, angle);
    double d(Dec x) => double.parse(x.toString());
    if (mode == NaturalMode.eqn &&
        (_eqnType == EqnType.quad || _eqnType == EqnType.cubic) &&
        !_coef[0][0].dec.isZero) {
      final k = [for (final v in _coef[0]) d(v.dec)];
      final label = StringBuffer('y = ');
      final deg = k.length - 1;
      for (final (i, c) in k.indexed) {
        if (c == 0) continue;
        final p = deg - i;
        final mag = c.abs();
        final num = mag == mag.roundToDouble()
            ? mag.toInt().toString()
            : mag.toString();
        if (label.length > 4) label.write(c < 0 ? ' − ' : ' + ');
        if (label.length == 4 && c < 0) label.write('−');
        if (p == 0 || num != '1') label.write(num);
        if (p >= 1) label.write('x');
        if (p >= 2) label.write(p == 2 ? '²' : '³');
      }
      return GraphSpec(
        curves: [
          (
            label.toString(),
            GraphFunction.of((x) => k.fold(0.0, (s, c) => s * x + c)),
          ),
        ],
      );
    }
    if (mode == NaturalMode.stat && _paired && _stat.items.length >= 2) {
      final pts = [
        for (final i in _stat.items) (x: d(i.x), y: d(i.y ?? Dec.zero)),
      ];
      GraphFunction? fit;
      try {
        _stat.estimateY(_stat.items.first.x); // throws when undefined
        fit = GraphFunction.of((x) {
          try {
            return d(_stat.estimateY(Dec.parse(x.toStringAsPrecision(15))));
          } on Object {
            return double.nan;
          }
        });
      } on Object {
        fit = null;
      }
      final name = _statTypeLines
          .join(' ')
          .split(RegExp(r'\s+\d:'))
          .map((s) => s.replaceFirst(RegExp(r'^\d:'), '').trim())
          .toList()[statType.index];
      return GraphSpec(
        curves: [if (fit != null) ('regression $name', fit)],
        points: pts,
      );
    }
    return null;
  }

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
    'mode': mode.name,
    'base': _base,
    'statType': statType.name,
    'stat': [
      for (final i in _stat.items)
        [i.x.toString(), i.y?.toString(), i.freq.toString()],
    ],
    'linear': {
      for (final e in _linear.entries)
        e.key: e.value.isMatrix
            ? [
                for (final row in e.value.matrix!)
                  [for (final x in row) x.toString()],
              ]
            : [for (final x in e.value.vector!) x.toString()],
    },
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
    final m = s['mode'];
    if (m is String) {
      mode = NaturalMode.values.firstWhere(
        (x) => x.name == m,
        orElse: () => NaturalMode.comp,
      );
      // Editors and menus are not restored; EQN / STAT open their menus
      // again when chosen.
      if (mode == NaturalMode.eqn) mode = NaturalMode.comp;
    }
    final b = s['base'];
    if (b is int && const {2, 8, 10, 16}.contains(b)) _base = b;
    final t = s['statType'];
    if (t is String) {
      final type = StatType.values.firstWhere(
        (x) => x.name == t,
        orElse: () => StatType.oneVar,
      );
      _setStatType(type);
      _editor = false;
    }
    final stat = s['stat'];
    if (stat is List) {
      _stat.clear();
      for (final row in stat) {
        if (row is! List || row.length != 3) continue;
        final [x, y, f] = row;
        if (x is! String || f is! String) continue;
        _stat.add(
          StatItem(
            Dec.parse(x),
            y: y is String ? Dec.parse(y) : null,
            freq: Dec.parse(f),
          ),
        );
      }
    }
    final linear = s['linear'];
    if (linear is Map) {
      _linear.clear();
      for (final MapEntry(:key, :value) in linear.entries) {
        if (key is! String || value is! List || value.isEmpty) continue;
        if (value.first is List) {
          _linear[key] = Value.matrix([
            for (final row in value)
              [for (final x in row as List) Dec.parse(x as String)],
          ]);
        } else {
          _linear[key] = Value.vector([
            for (final x in value) Dec.parse(x as String),
          ]);
        }
      }
    }
  }
}
