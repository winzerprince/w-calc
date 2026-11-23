import 'dart:math' as math;

import 'angle_unit.dart';
import 'calc_key.dart';
import 'display_state.dart';
import 'eval/evaluator.dart';
import 'eqn/solvers.dart';
import 'eval/solve.dart';
import 'format/number_format.dart';
import 'format/value_format.dart';
import 'input/token.dart';
import 'number/dec.dart';
import 'number/frac.dart';
import 'number/value.dart';
import 'stats/stats.dart';

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
const _sclMenu = _Menu('Scl Mode All', {1: '1', 5: '2', 10: '3'});

/// EQN type selection (manual p.59-61).
const _unknownsPage = _Menu('Unknowns?→', {0: '2', 4: '3'});
const _degreePage = _Menu('←Degree?', {1: '2', 5: '3'});

/// Coefficient names per equation type.
const _eqnNames = {
  'simul2': ['a1', 'b1', 'c1', 'a2', 'b2', 'c2'],
  'simul3': [
    'a1',
    'b1',
    'c1',
    'd1',
    'a2',
    'b2',
    'c2',
    'd2',
    'a3',
    'b3',
    'c3',
    'd3',
  ],
  'poly2': ['a', 'b', 'c'],
  'poly3': ['a', 'b', 'c', 'd'],
};

/// BASE LOGIC menu (x⁻¹ repeatedly pages through).
const _logicPages = [
  _Menu('And Or Xnor', {1: '1', 4: '2', 8: '3'}),
  _Menu('Xor Not Neg', {1: '1', 4: '2', 8: '3'}),
  _Menu(' d  h  b  o', {1: '1', 4: '2', 7: '3', 10: '4'}),
];
const _logicTokens = [
  [Tok.logicAnd, Tok.logicOr, Tok.logicXnor],
  [Tok.logicXor, Tok.logicNot, Tok.logicNeg],
  [Tok.baseD, Tok.baseH, Tok.baseB, Tok.baseO],
];
const _clrScl = _Menu('Scl', {});

/// REG type selection (MODE MODE 2), paged with ◀ ▶.
const _regPages = [
  _Menu('Lin Log Exp→', {1: '1', 5: '2', 9: '3'}),
  _Menu('←Pwr Inv Quad', {2: '1', 6: '2', 10: '3'}),
];

/// Data memory is full (manual p.49).
const _dataFullMenu = _Menu('EditOFF ESC', {1: '1', 8: '2'});

const _sdSumPage = _Menu('Σx² Σx n', {1: '1', 4: '2', 7: '3'});
const _sdVarPage = _Menu('\uE000 xσn xσn-1', {0: '1', 3: '2', 8: '3'});
const _distrPage = _Menu('P( Q( R( →t', {0: '1', 3: '2', 6: '3', 9: '4'});
const _regSumPages = [
  _Menu('Σx² Σx n→', {1: '1', 4: '2', 7: '3'}),
  _Menu('←Σy² Σy Σxy→', {2: '1', 5: '2', 9: '3'}),
  _Menu('←Σx³ Σx²y Σx⁴', {2: '1', 6: '2', 10: '3'}),
];
const _regVarPages = [
  _Menu('\uE000 xσn xσn-1→', {0: '1', 3: '2', 8: '3'}),
  _Menu('←\uE001 yσn yσn-1→', {1: '1', 4: '2', 9: '3'}),
  _Menu('←A B r→', {1: '1', 3: '2', 5: '3'}),
  _Menu('←\uE002 \uE003', {1: '1', 3: '2'}),
];
const _quadVarPages = [
  _Menu('\uE000 xσn xσn-1→', {0: '1', 3: '2', 8: '3'}),
  _Menu('←\uE001 yσn yσn-1→', {1: '1', 4: '2', 9: '3'}),
  _Menu('←A B C→', {1: '1', 3: '2', 5: '3'}),
  _Menu('←\uE0021 \uE0022 \uE003', {1: '1', 4: '2', 7: '3'}),
];

/// Tokens inserted by each statistics menu page (index = digit − 1).
const _statMenuTokens = <_Menu, List<Tok>>{
  _sdSumPage: [Tok.statSumX2, Tok.statSumX, Tok.statN],
  _sdVarPage: [Tok.statMeanX, Tok.statSigmaX, Tok.statSampleX],
  _distrPage: [Tok.distP, Tok.distQ, Tok.distR, Tok.toT],
};

/// Disp setup screens (MODE … 1), paged with ◀ ▶.
const _engPage = _Menu('EngON EngOFF', {1: '1', 7: '2'});
const _complexPage = _Menu('a+bi r∠θ', {1: '1', 6: '2'});
const _fractionPage = _Menu('ab/c d/c', {1: '1', 6: '2'});
const _commaPage = _Menu('Dot Comma', {1: '1', 5: '2'});

/// Calculation modes implemented so far.
enum CalcMode { comp, cmplx, sd, reg, base, eqn }

/// CLR confirmations (press = to execute, AC to cancel).
const _clrMcl = _Menu('Mcl', {});
const _clrMode = _Menu('Mode', {});
const _clrAll = _Menu('All', {});

/// One calculation-history entry: what was typed and what it gave.
class _Entry {
  _Entry(this.tokens, this.value);

  final List<Tok> tokens;
  final Value value;

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

/// CALC / SOLVE session: the stored expression and its variable prompts.
class _EquationSession {
  _EquationSession({
    required this.solve,
    required this.tokens,
    required this.variables,
  });

  final bool solve;
  final List<Tok> tokens;

  /// Variables to prompt for, in order of first appearance.
  final List<Tok> variables;
  int index = 0;

  /// Value being typed at the current prompt.
  List<Tok> typed = [];

  /// True while prompting; false while the result is shown.
  bool prompting = true;
}

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

  Value _ans = Value.zero;
  Value? _resultValue;
  CalcError? _error;
  DisplaySettings _settings = const DisplaySettings();
  AngleUnit _angle = AngleUnit.deg;
  final Map<String, Value> _vars = {};

  /// Result conversions (a b/c, d/c, °′″, ENG) applied to the shown result.
  ResultView _view = ResultView.auto;
  bool _flipFractionStyle = false;
  int? _engExponent;

  /// Upper-line text while a result is shown, when it differs from the input
  /// (current statement of a multi-statement, `A=` after RCL).
  String? _upperOverride;

  /// Token an operator continues from after a result (Ans, or the recalled variable).
  Tok _continueWith = Tok.ans;

  final List<_Entry> _history = [];
  int? _browse; // history index shown in the result phase

  _EquationSession? _equation;

  CalcMode _mode = CalcMode.comp;

  // EQN mode: chosen equation type, coefficients per type, prompt / answers.
  String? _eqnKind;
  final Map<String, List<Dec>> _eqnCoefficients = {
    for (final e in _eqnNames.entries)
      e.key: List.filled(e.value.length, Dec.zero),
  };
  int _eqnIndex = 0;
  List<Tok> _eqnTyped = [];
  List<Value>? _eqnSolutions;
  int _eqnSolution = 0;

  /// BASE mode number system: 10, 16, 2 or 8.
  int _base = 10;

  static const _baseLetters = {10: 'd', 16: 'h', 2: 'b', 8: 'o'};

  /// SD/REG statistical memory.
  final StatData _stats = StatData();

  /// Items at or after this index were registered with EditOFF (not browsable).
  int? _editLimit;

  /// Item waiting while the Data Full screen is shown.
  StatItem? _pendingItem;

  /// Last registered item (DT pressed again repeats it).
  StatItem? _lastItem;

  /// Data display (▲ ▼ in SD/REG): item index and field (0 x, 1 y, 2 freq).
  (int, int)? _dataView;
  List<Tok> _dataTyped = [];

  bool get _statMode => _mode == CalcMode.sd || _mode == CalcMode.reg;

  /// Data items that can still be shown and edited.
  int get _editableItems => _editLimit ?? _stats.items.length;

  /// CMPLX: which part of a complex result is shown (0 = re or r, 1 = im or θ).
  int _complexPart = 0;

  /// CMPLX: ▶r∠θ (true) / ▶a+bi (false) command on the last expression.
  bool? _polarCommand;

  CalcMode get mode => _mode;

  /// Disp setup pages for the current mode (a+bi / r∠θ only in CMPLX).
  List<_Menu> get _dispPages => [
    _engPage,
    if (_mode == CalcMode.cmplx || _mode == CalcMode.eqn) _complexPage,
    _fractionPage,
    _commaPage,
  ];

  bool get _polarShown =>
      _mode == CalcMode.cmplx && (_polarCommand ?? _settings.polarComplex);

  /// CMPLX result has a second part to toggle with SHIFT = (Re⇔Im).
  bool get _hasSecondPart =>
      _mode == CalcMode.cmplx &&
      _resultValue != null &&
      (_resultValue!.isComplex || _polarShown);

  /// CONST / CONV number entry: (is CONV, digits typed so far).
  (bool, String)? _codePrompt;

  /// Multi-statement execution: statement ranges and the one shown.
  List<(int, int)> _statements = const [];
  int _statement = 0;

  AngleUnit get angleUnit => _angle;
  DisplayFormat get displayFormat => _settings.format;
  DisplaySettings get displaySettings => _settings;

  DisplayFormat get _format => _settings.format;

  bool get _midMulti =>
      _phase == _Phase.result && _statement < _statements.length - 1;

  FormattedNumber get _result {
    final v = _resultValue;
    if (_mode == CalcMode.base) {
      final letter = _baseLetters[_base];
      if (v == null) return FormattedNumber('0.', null, letter);
      try {
        return FormattedNumber('${baseOutput(v.dec, _base)}.', null, letter);
      } on CalcError {
        return FormattedNumber('', null, letter);
      }
    }
    if (v == null) return const FormattedNumber('0.');
    if (_mode == CalcMode.cmplx && (v.isComplex || _polarShown)) {
      final part = _complexPart == 1
          ? (_polarShown ? v.argument(_angle) : v.imag)
          : (_polarShown ? v.magnitude() : v.dec);
      return formatValue(Value.dec(part), _settings);
    }
    final settings = _flipFractionStyle
        ? _settings.copyWith(improperFractions: !_settings.improperFractions)
        : _settings;
    return formatValue(v, settings, view: _view, engExponent: _engExponent);
  }

  /// A new result: forget conversions applied to the previous one.
  void _setResult(Value v) {
    _complexPart = 0;
    _resultValue = v;
    _view = ResultView.auto;
    _flipFractionStyle = false;
    _engExponent = null;
  }

  DisplayState get display {
    final browse = _browse;
    final showScroll = _phase == _Phase.result && browse != null && !_midMulti;
    final indicators = {
      if (_modifier == _Modifier.shift) Indicator.shift,
      if (_modifier == _Modifier.alpha) Indicator.alpha,
      if (_hyp) Indicator.hyp,
      if (_pending == _Pending.sto) Indicator.sto,
      if (_pending == _Pending.rcl) Indicator.rcl,
      if (!(_vars['M'] ?? Value.zero).dec.isZero) Indicator.memory,
      if (_settings.engOn) Indicator.eng,
      if (_format.mode == DisplayMode.fix) Indicator.fix,
      if (_format.mode == DisplayMode.sci) Indicator.sci,
      _angle.indicator,
      if (showScroll && browse > 0) Indicator.scrollUp,
      if (showScroll && browse < _history.length - 1) Indicator.scrollDown,
      if (_midMulti) Indicator.disp,
      if (_mode == CalcMode.cmplx) Indicator.cmplx,
      if (_mode == CalcMode.sd) Indicator.sd,
      if (_mode == CalcMode.reg) Indicator.reg,
      if (_mode == CalcMode.cmplx && _settings.polarComplex) Indicator.polar,
      if (_phase == _Phase.result && _hasSecondPart && !_midMulti) ...[
        Indicator.reIm,
        if (_complexPart == 1)
          _polarShown ? Indicator.angleMark : Indicator.imaginary,
      ],
    };
    final kind = _eqnKind;
    if (_mode == CalcMode.eqn &&
        kind != null &&
        _menu == null &&
        _phase != _Phase.error) {
      return _eqnDisplay(kind, indicators);
    }
    final view = _dataView;
    if (view != null) {
      final (index, field) = view;
      final item = _stats.items[index];
      final label = ['x', 'y', 'Freq'][field];
      final upper = '$label${index + 1}=';
      if (_dataTyped.isNotEmpty) {
        final typed = _dataTyped.map((t) => t.text).join();
        return DisplayState(
          upper: upper,
          lower: typed.contains('.') || typed.contains('E') ? typed : '$typed.',
          indicators: indicators,
        );
      }
      final value = switch (field) {
        0 => item.x,
        1 => item.y ?? Dec.zero,
        _ => item.freq,
      };
      final f = formatValue(Value.dec(value), _settings);
      return DisplayState(
        upper: upper,
        lower: f.mantissa,
        exponent: f.exponent,
        indicators: indicators,
      );
    }
    final eq = _equation;
    if (eq != null && eq.prompting) {
      final name = eq.variables[eq.index].text;
      if (eq.typed.isEmpty) {
        final current = formatValue(_vars[name] ?? Value.zero, _settings);
        return DisplayState(
          upper: '$name?',
          lower: current.mantissa,
          exponent: current.exponent,
          indicators: indicators,
        );
      }
      final typed = eq.typed.map((t) => t.text).join();
      return DisplayState(
        upper: name,
        lower: typed.contains('.') || typed.contains('E') ? typed : '$typed.',
        indicators: indicators,
      );
    }
    final code = _codePrompt;
    if (code != null) {
      final (conv, digits) = code;
      return DisplayState(
        upper: '${conv ? 'CONV' : 'CONST'}${digits.padRight(2, '-')}',
        lower: '',
        indicators: indicators,
      );
    }
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
        engSymbol: result.engSymbol,
        decimalComma: _settings.decimalComma,
        indicators: indicators,
      );
    }
    return DisplayState(
      upper: _clip(text, _windowStart),
      lower: result.mantissa,
      exponent: result.exponent,
      engSymbol: result.engSymbol,
      decimalComma: _settings.decimalComma,
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
    if (_codePrompt != null) {
      _pressCode(key);
      return;
    }
    if (_equation != null && _pressEquation(key)) return;
    if (_dataView != null && _pressDataView(key)) return;
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
    if (_mode == CalcMode.eqn) {
      _modifier = _Modifier.none;
      _pressEqn(key, modifier);
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

    if (_mode == CalcMode.base && _pressBase(key, modifier)) return;
    switch ((modifier, key)) {
      case (_Modifier.none, CalcKey.mPlus) when _statMode:
        _registerData();
      case (_Modifier.shift, CalcKey.mPlus) when _statMode:
        _deleteLastData();
      case (_Modifier.shift, CalcKey.comma) when _statMode:
        _enter(Tok.freqSep);
      case (_Modifier.shift, CalcKey.d1) when _statMode:
        _menu = _mode == CalcMode.sd ? _sdSumPage : _regSumPages.first;
      case (_Modifier.shift, CalcKey.d2) when _statMode:
        _menu = _mode == CalcMode.sd
            ? _sdVarPage
            : (_stats.type == RegressionType.quad
                      ? _quadVarPages
                      : _regVarPages)
                  .first;
      case (_Modifier.shift, CalcKey.d3) when _statMode:
        if (_mode == CalcMode.sd) _menu = _distrPage;
      case (_Modifier.none, CalcKey.up || CalcKey.down) when _statMode:
        _openDataView(key == CalcKey.up);
      case (_Modifier.shift, CalcKey.mode) when _statMode:
        _menu = _sclMenu;
      case (_Modifier.shift, CalcKey.equals) when _statMode:
        break; // % is not available in SD/REG.
      case (_Modifier.shift, CalcKey.equals) when _mode == CalcMode.cmplx:
        if (_phase == _Phase.result && _hasSecondPart) {
          _complexPart = 1 - _complexPart;
        }
      case (_, CalcKey.integrate)
          when _mode == CalcMode.cmplx && modifier != _Modifier.alpha:
        break; // ∫ and d/dx: COMP only.
      case (_Modifier.shift, CalcKey.calc) when _mode == CalcMode.cmplx:
        break; // SOLVE: COMP only.
      case (_Modifier.none, CalcKey.mode):
        _menu = _modePages.first;
      case (_Modifier.shift, CalcKey.mode):
        _menu = _clrMenu;
      case (_Modifier.shift, CalcKey.ans):
        _menu = _drgMenu;
      case (_Modifier.none, CalcKey.calc):
        _startEquation(solve: false);
      case (_Modifier.shift, CalcKey.calc):
        _startEquation(solve: true);
      case (_Modifier.alpha, CalcKey.calc):
        _enter(Tok.eqSign);
      case (_Modifier.none, CalcKey.constant):
        _codePrompt = (false, '');
      case (_Modifier.shift, CalcKey.constant):
        _codePrompt = (true, '');
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
      case (_Modifier.shift, CalcKey.equals):
        _percent();
      case (_, CalcKey.fraction || CalcKey.degMinSec || CalcKey.eng)
          when _phase == _Phase.result &&
              !_midMulti &&
              !(_mode == CalcMode.cmplx && key == CalcKey.eng):
        _convertResult(key, modifier == _Modifier.shift);
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
        final tok = _mode == CalcMode.cmplx
            ? (_complexToken(key, modifier) ??
                  _tokenFor(key, modifier, hyp, engOn: _settings.engOn))
            : _tokenFor(key, modifier, hyp, engOn: _settings.engOn);
        if (tok != null) _enter(tok);
    }
  }

  /// Token for [key] under [modifier]/[hyp], or null if the key does nothing yet.
  static Tok? _tokenFor(
    CalcKey key,
    _Modifier modifier,
    bool hyp, {
    bool engOn = false,
  }) {
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
      if (digit == 0) return Tok.rnd;
      return engOn ? _engSymbolKeys[digit - 1] : null;
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
      CalcKey.add when shift => Tok.pol,
      CalcKey.integrate => shift ? Tok.derivative : Tok.integral,
      CalcKey.subtract when shift => Tok.rec,
      _ when shift => null,
      CalcKey.comma => Tok.comma,
      CalcKey.fraction => Tok.fracSep,
      CalcKey.degMinSec => Tok.dms,
      CalcKey.add => Tok.add,
      CalcKey.subtract => Tok.subtract,
      CalcKey.negative => Tok.negative,
      CalcKey.openParen => Tok.openParen,
      CalcKey.closeParen => Tok.closeParen,
      CalcKey.ans => Tok.ans,
      _ => null,
    };
  }

  /// CMPLX-mode key meanings (purple legends), or null for the common ones.
  static Tok? _complexToken(CalcKey key, _Modifier modifier) =>
      switch ((modifier, key)) {
        (_Modifier.none, CalcKey.eng) => Tok.imagUnit,
        (_Modifier.shift, CalcKey.openParen) => Tok.cArg,
        (_Modifier.shift, CalcKey.closeParen) => Tok.cAbs,
        (_Modifier.shift, CalcKey.comma) => Tok.conjg,
        (_Modifier.shift, CalcKey.negative) => Tok.angle,
        (_Modifier.shift, CalcKey.add) => Tok.toPolar,
        (_Modifier.shift, CalcKey.subtract) => Tok.toRect,
        _ => null,
      };

  /// SHIFT 1…9 with EngON: f p n μ m k M G T.
  static const _engSymbolKeys = [
    Tok.engFemto,
    Tok.engPico,
    Tok.engNano,
    Tok.engMicro,
    Tok.engMilli,
    Tok.engKilo,
    Tok.engMega,
    Tok.engG,
    Tok.engT,
  ];

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
    if (_phase == _Phase.result &&
        _tokens.isNotEmpty &&
        _tokens.last == Tok.percent &&
        (tok == Tok.add || tok == Tok.subtract)) {
      // Mark-up / discount: A × B % + → A + A·B/100 (manual p.21).
      _tokens.add(tok);
      _execute();
      return;
    }
    if (_phase == _Phase.result) {
      final continueWith = _continueWith;
      _clearInput();
      if (tok.kind == TokKind.binary ||
          tok.kind == TokKind.postfix ||
          tok.kind == TokKind.formatCommand) {
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

  /// Two-digit CONST / CONV number; 01-40 inserts the token, AC cancels.
  void _pressCode(CalcKey key) {
    final (conv, digits) = _codePrompt!;
    _modifier = _Modifier.none;
    if (key == CalcKey.ac) {
      _codePrompt = null;
      return;
    }
    final d = key.digit;
    if (d == null) return;
    if (digits.isEmpty) {
      if (d <= 4) _codePrompt = (conv, '$d');
      return;
    }
    final n = int.parse('$digits$d');
    if (n < 1 || n > 40) return;
    _codePrompt = null;
    _enter((conv ? Tok.conversions : Tok.constants)[n - 1]);
  }

  // ------------------------------------------------------------------ CALC / SOLVE

  /// Starts CALC or SOLVE on the expression being edited / last calculated.
  void _startEquation({required bool solve}) {
    if (_tokens.isEmpty || _phase == _Phase.error) return;
    final tokens = List.of(_tokens);
    final assigned =
        !solve &&
            tokens.length > 1 &&
            tokens[0].kind == TokKind.variable &&
            tokens[1] == Tok.eqSign
        ? tokens[0]
        : null;
    final variables = <Tok>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind == TokKind.variable &&
          !variables.contains(t) &&
          !(i == 0 && t == assigned)) {
        variables.add(t);
      }
    }
    _insert = false;
    _phase = _Phase.editing;
    final session = _EquationSession(
      solve: solve,
      tokens: tokens,
      variables: variables,
    );
    _equation = session;
    if (variables.isEmpty) {
      if (solve) {
        _endEquation();
        _showError(const CalcError(CalcErrorKind.syntax));
      } else {
        _calcResult(session);
      }
    }
  }

  /// Handles a key during CALC/SOLVE. Returns false to let normal handling
  /// take the key (the session has then ended).
  bool _pressEquation(CalcKey key) {
    final eq = _equation!;
    final modifier = _modifier;
    if (key == CalcKey.shift || key == CalcKey.alpha) return false;
    _modifier = _Modifier.none;
    if (key == CalcKey.ac) {
      _endEquation();
      _clearInput();
      _setResult(Value.zero);
      _resultValue = null;
      return true;
    }
    final solveKey = modifier == _Modifier.shift && key == CalcKey.calc;
    if (!eq.prompting) {
      // Result shown: CALC / = (CALC) or SOLVE restart the prompts.
      if ((!eq.solve &&
              modifier == _Modifier.none &&
              (key == CalcKey.calc || key == CalcKey.equals)) ||
          (eq.solve && (solveKey || key == CalcKey.equals))) {
        eq.prompting = true;
        eq.typed = [];
        if (!eq.solve) eq.index = 0;
        return true;
      }
      _endEquation();
      return false;
    }
    if (modifier == _Modifier.none) {
      final d = key.digit;
      final tok = d != null
          ? Tok.digits[d]
          : switch (key) {
              CalcKey.dot => Tok.point,
              CalcKey.exp => Tok.exp,
              CalcKey.negative => Tok.negative,
              _ => null,
            };
      if (tok != null) {
        if (eq.typed.length < 20) eq.typed.add(tok);
        return true;
      }
    }
    switch ((modifier, key)) {
      case (_Modifier.none, CalcKey.del):
        if (eq.typed.isNotEmpty) eq.typed.removeLast();
      case (_Modifier.none, CalcKey.equals):
        if (!_commitTyped(eq)) return true;
        if (eq.index < eq.variables.length - 1) {
          eq.index++;
        } else if (!eq.solve) {
          _calcResult(eq);
        }
      case (_Modifier.none, CalcKey.up) when eq.solve:
        eq.typed = [];
        if (eq.index > 0) eq.index--;
      case (_Modifier.none, CalcKey.down) when eq.solve:
        eq.typed = [];
        if (eq.index < eq.variables.length - 1) eq.index++;
      case _ when solveKey && eq.solve:
        if (_commitTyped(eq)) _solve(eq);
      default:
        break; // Other keys are ignored while prompting.
    }
    return true;
  }

  /// Stores the typed value into the prompted variable. False on bad input.
  bool _commitTyped(_EquationSession eq) {
    if (eq.typed.isEmpty) return true;
    try {
      final v = evaluateValue(eq.typed, EvalContext(ans: _ans));
      _vars[eq.variables[eq.index].text] = v;
      eq.typed = [];
      return true;
    } on CalcError catch (e) {
      _endEquation();
      _showError(CalcError(e.kind));
      return false;
    }
  }

  EvalContext _context() => EvalContext(
    ans: _ans,
    angle: _angle,
    format: _format,
    variables: _vars,
    improperFractions: _settings.improperFractions,
    store: (name, value) => _vars[name] = value,
    stats: _statMode ? _stats : null,
    base: _mode == CalcMode.base ? _base : null,
    random: _random,
  );

  void _calcResult(_EquationSession eq) {
    var tokens = eq.tokens;
    Tok? target;
    if (tokens.length > 1 &&
        tokens[0].kind == TokKind.variable &&
        tokens[1] == Tok.eqSign) {
      target = tokens[0];
      tokens = tokens.sublist(2);
    }
    try {
      // Multi-statements: evaluate in order, show the last result.
      var start = 0;
      Value? value;
      for (var i = 0; i <= tokens.length; i++) {
        if (i == tokens.length || tokens[i] == Tok.colon) {
          final part = tokens.sublist(start, i);
          value = _guardedEval(part, start + (target == null ? 0 : 2));
          _ans = value;
          start = i + 1;
        }
      }
      if (target != null) _vars[target.text] = value!;
      _setResult(value!);
      _tokens = List.of(eq.tokens);
      _cursor = _tokens.length;
      _phase = _Phase.result;
      eq.prompting = false;
    } on CalcError catch (e) {
      _endEquation();
      _tokens = List.of(eq.tokens);
      _showError(e);
    }
  }

  Value _guardedEval(List<Tok> tokens, int offset) {
    try {
      return evaluateValue(tokens, _context());
    } on CalcError catch (e) {
      throw CalcError(e.kind, offset + (e.position ?? 0));
    }
  }

  void _solve(_EquationSession eq) {
    final variable = eq.variables[eq.index];
    final tokens = eq.tokens;
    final forbidden = tokens.any(
      (t) =>
          t == Tok.integral ||
          t == Tok.derivative ||
          t == Tok.pol ||
          t == Tok.rec ||
          t == Tok.colon,
    );
    final eqAt = tokens.indexOf(Tok.eqSign);
    if (forbidden || tokens.lastIndexOf(Tok.eqSign) != eqAt) {
      _endEquation();
      _tokens = List.of(tokens);
      _showError(const CalcError(CalcErrorKind.syntax));
      return;
    }
    final left = eqAt < 0 ? tokens : tokens.sublist(0, eqAt);
    final right = eqAt < 0 ? const <Tok>[] : tokens.sublist(eqAt + 1);
    Dec f(Dec x) {
      final saved = _vars[variable.text];
      _vars[variable.text] = Value.dec(x);
      try {
        final l = evaluateValue(left, _context()).dec;
        final r = right.isEmpty
            ? Dec.zero
            : evaluateValue(right, _context()).dec;
        return l - r;
      } finally {
        if (saved == null) {
          _vars.remove(variable.text);
        } else {
          _vars[variable.text] = saved;
        }
      }
    }

    try {
      final start = (_vars[variable.text] ?? Value.zero).dec;
      final x = newtonSolve(f, start);
      final v = Value.dec(x);
      _vars[variable.text] = v;
      _ans = v;
      _setResult(v);
      _tokens = [variable];
      _cursor = 1;
      _upperOverride = '${variable.text}=';
      _phase = _Phase.result;
      eq.prompting = false;
    } on CalcError catch (e) {
      _endEquation();
      _tokens = List.of(tokens);
      _showError(
        CalcError(
          e.kind == CalcErrorKind.cantSolve ? e.kind : CalcErrorKind.cantSolve,
        ),
      );
    }
  }

  void _endEquation() => _equation = null;

  // ------------------------------------------------------------------ menus

  void _pressInMenu(CalcKey key) {
    final menu = _menu!;
    _modifier = _Modifier.none;
    if (key == CalcKey.ac) {
      _menu = null;
      return;
    }
    final pages = _dispPages;
    if (pages.contains(menu)) {
      final i = pages.indexOf(menu);
      if (key == CalcKey.right && i < pages.length - 1) _menu = pages[i + 1];
      if (key == CalcKey.left && i > 0) _menu = pages[i - 1];
      final d = key.digit;
      if (d == 1 || d == 2) {
        _settings = switch (menu) {
          _engPage => _settings.copyWith(engOn: d == 1),
          _complexPage => _settings.copyWith(polarComplex: d == 2),
          _fractionPage => _settings.copyWith(improperFractions: d == 2),
          _ => _settings.copyWith(decimalComma: d == 2),
        };
        _menu = null;
      }
      return;
    }
    if (key == CalcKey.mode && _modePages.contains(menu)) {
      // After the last setup page, MODE returns to the calculation screen.
      final next = _modePages.indexOf(menu) + 1;
      _menu = next < _modePages.length ? _modePages[next] : null;
      return;
    }
    if (identical(menu, _unknownsPage) || identical(menu, _degreePage)) {
      final simul = identical(menu, _unknownsPage);
      if (key == CalcKey.right && simul) _menu = _degreePage;
      if (key == CalcKey.left && !simul) _menu = _unknownsPage;
      final d = key.digit;
      if (d == 2 || d == 3) {
        _menu = null;
        _eqnKind = '${simul ? 'simul' : 'poly'}$d';
        _eqnIndex = 0;
        _eqnTyped = [];
        _eqnSolutions = null;
      }
      return;
    }
    if (_logicPages.contains(menu)) {
      final i = _logicPages.indexOf(menu);
      if (key == CalcKey.reciprocal) {
        _menu = _logicPages[(i + 1) % _logicPages.length];
        return;
      }
      final d = key.digit;
      final tokens = _logicTokens[i];
      if (d != null && d >= 1 && d <= tokens.length) {
        _menu = null;
        _enter(tokens[d - 1]);
      }
      return;
    }
    if (_regPages.contains(menu)) {
      final i = _regPages.indexOf(menu);
      if (key == CalcKey.right && i == 0) _menu = _regPages[1];
      if (key == CalcKey.left && i == 1) _menu = _regPages[0];
      final d = key.digit;
      if (d != null && d >= 1 && d <= 3) {
        _selectRegression(RegressionType.values[i * 3 + d - 1]);
      }
      return;
    }
    if (identical(menu, _dataFullMenu)) {
      final d = key.digit;
      final item = _pendingItem;
      if ((d == 1 || d == 2) && item != null) {
        _menu = null;
        _pendingItem = null;
        if (d == 1) {
          _editLimit ??= _stats.items.length;
          _addItem(item);
        }
      }
      return;
    }
    final statPages = _statMenuPages(menu);
    if (statPages != null) {
      final i = statPages.indexOf(menu);
      if (key == CalcKey.right && i < statPages.length - 1) {
        _menu = statPages[i + 1];
      }
      if (key == CalcKey.left && i > 0) _menu = statPages[i - 1];
      final d = key.digit;
      final tokens = _statTokens(menu);
      if (d != null && d >= 1 && d <= tokens.length) {
        _menu = null;
        _enter(tokens[d - 1]);
      }
      return;
    }
    if (identical(menu, _clrMcl) ||
        identical(menu, _clrMode) ||
        identical(menu, _clrAll) ||
        identical(menu, _clrScl)) {
      if (key == CalcKey.equals) _clear(menu);
      return;
    }
    final d = key.digit;
    if (d == null) return;

    if (identical(menu, _clrMenu) || identical(menu, _sclMenu)) {
      final first = identical(menu, _sclMenu) ? _clrScl : _clrMcl;
      if (d >= 1 && d <= 3) _menu = [first, _clrMode, _clrAll][d - 1];
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
      _settings = _settings.copyWith(format: DisplayFormat.fix(d));
      _menu = null;
      return;
    }
    if (identical(menu, _sciPrompt)) {
      _settings = _settings.copyWith(format: DisplayFormat.sci(d));
      _menu = null;
      return;
    }
    if (identical(menu, _normPrompt)) {
      if (d != 1 && d != 2) return;
      _settings = _settings.copyWith(
        format: d == 1
            ? const DisplayFormat.norm1()
            : const DisplayFormat.norm2(),
      );
      _menu = null;
      return;
    }
    switch ((_modePages.indexOf(menu), d)) {
      case (0, 1 || 2): // COMP, CMPLX
        _setMode(d == 1 ? CalcMode.comp : CalcMode.cmplx);
      case (1, 1): // SD
        _setMode(CalcMode.sd);
      case (2, 1): // EQN
        _setMode(CalcMode.eqn);
        _eqnKind = null;
        _menu = _unknownsPage;
      case (1, 3): // BASE
        _setMode(CalcMode.base);
        _base = 10;
      case (3 || 4 || 5, _) when _mode == CalcMode.base:
        break; // Angle unit and display setup are fixed in BASE mode.
      case (1, 2): // REG → regression type
        _menu = _regPages.first;
      case (3, 1 || 2 || 3):
        _angle = AngleUnit.values[d - 1];
        _menu = null;
      case (4, 1):
        _menu = _fixPrompt;
      case (4, 2):
        _menu = _sciPrompt;
      case (4, 3):
        _menu = _normPrompt;
      case (5, 1):
        _menu = _engPage;
      default:
        // CMPLX, SD, REG, BASE, EQN, MAT, VCT, Disp: later milestones.
        break;
    }
  }

  /// Executes a confirmed CLR choice.
  void _clear(_Menu which) {
    if (identical(which, _clrScl)) {
      _clearStats();
      _menu = null;
      _clearInput();
      _resultValue = null;
      return;
    }
    if (identical(which, _clrAll)) _clearStats();
    if (identical(which, _clrMode)) {
      _setMode(CalcMode.comp);
    }
    if (!identical(which, _clrMode)) _vars.clear();
    if (!identical(which, _clrMcl)) {
      _angle = AngleUnit.deg;
      _settings = const DisplaySettings();
      _history.clear();
    }
    if (identical(which, _clrAll)) _ans = Value.zero;
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
      _setResult(value);
    } else {
      _setResult(_vars[variable.text] ?? Value.zero);
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
    final m = _vars['M'] ?? Value.zero;
    try {
      _vars['M'] = sign > 0 ? m + value : m - value;
    } on CalcError catch (e) {
      _showError(e);
      return;
    }
    _ans = value;
    _setResult(value);
  }

  /// The value STO / M+ act on: evaluates pending input (like =), otherwise
  /// the value on the display. Null if evaluation failed (error shown).
  Value? _commitValue() {
    if (_phase == _Phase.editing && _tokens.isNotEmpty) {
      _execute();
      while (_midMulti) {
        _execute();
      }
      return _phase == _Phase.result ? _resultValue : null;
    }
    return _resultValue ?? Value.zero;
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

  /// Switches calculation mode: clears input, result and history.
  void _setMode(CalcMode mode) {
    _menu = null;
    if (mode == _mode) return;
    _mode = mode;
    _clearInput();
    _resultValue = null;
    _history.clear();
    _clearStats();
  }

  // ------------------------------------------------------------------ EQN

  DisplayState _eqnDisplay(String kind, Set<Indicator> indicators) {
    final names = _eqnNames[kind]!;
    final solutions = _eqnSolutions;
    if (solutions != null) {
      final simul = kind.startsWith('simul');
      final name = simul
          ? const ['x', 'y', 'z'][_eqnSolution]
          : 'x${_eqnSolution + 1}';
      final v = solutions[_eqnSolution];
      final polar = _settings.polarComplex && v.isComplex;
      final part = _complexPart == 1
          ? (polar ? v.argument(_angle) : v.imag)
          : (polar ? v.magnitude() : v.dec);
      final f = formatValue(Value.dec(part), _settings);
      return DisplayState(
        upper: '$name=',
        lower: f.mantissa,
        exponent: f.exponent,
        indicators: {
          ...indicators,
          if (_eqnSolution > 0) Indicator.scrollUp,
          if (_eqnSolution < solutions.length - 1) Indicator.scrollDown,
          if (v.isComplex) Indicator.reIm,
          if (v.isComplex && _complexPart == 1)
            polar ? Indicator.angleMark : Indicator.imaginary,
        },
      );
    }
    final name = names[_eqnIndex];
    final arrows = {
      if (_eqnIndex > 0) Indicator.scrollUp,
      if (_eqnIndex < names.length - 1) Indicator.scrollDown,
    };
    if (_eqnTyped.isNotEmpty) {
      final typed = _eqnTyped.map((t) => t.text).join();
      return DisplayState(
        upper: name,
        lower: typed.contains('.') || typed.contains('E') ? typed : '$typed.',
        indicators: {...indicators, ...arrows},
      );
    }
    final f = formatValue(
      Value.dec(_eqnCoefficients[kind]![_eqnIndex]),
      _settings,
    );
    return DisplayState(
      upper: '$name?',
      lower: f.mantissa,
      exponent: f.exponent,
      indicators: {...indicators, ...arrows},
    );
  }

  void _pressEqn(CalcKey key, _Modifier modifier) {
    if (key == CalcKey.mode && modifier == _Modifier.none) {
      _menu = _modePages.first;
      return;
    }
    if (key == CalcKey.mode && modifier == _Modifier.shift) {
      _menu = _clrMenu;
      return;
    }
    if (_phase == _Phase.error) {
      if (key == CalcKey.ac || key == CalcKey.left || key == CalcKey.right) {
        _phase = _Phase.editing;
        _error = null;
        _eqnIndex = 0;
      }
      return;
    }
    final kind = _eqnKind;
    if (kind == null) {
      _menu = _unknownsPage;
      return;
    }
    final names = _eqnNames[kind]!;
    if (_eqnSolutions != null) {
      switch ((modifier, key)) {
        case (_Modifier.none, CalcKey.up):
          if (_eqnSolution > 0) _eqnSolution--;
          _complexPart = 0;
        case (_Modifier.none, CalcKey.down):
          if (_eqnSolution < _eqnSolutions!.length - 1) _eqnSolution++;
          _complexPart = 0;
        case (_Modifier.shift, CalcKey.equals):
          if (_eqnSolutions![_eqnSolution].isComplex) {
            _complexPart = 1 - _complexPart;
          }
        case (_Modifier.none, CalcKey.ac):
          _eqnSolutions = null;
          _eqnIndex = 0;
        default:
          break;
      }
      return;
    }
    if (modifier == _Modifier.none) {
      final d = key.digit;
      final tok = d != null
          ? Tok.digits[d]
          : switch (key) {
              CalcKey.dot => Tok.point,
              CalcKey.exp => Tok.exp,
              CalcKey.negative => Tok.negative,
              _ => null,
            };
      if (tok != null) {
        if (_eqnTyped.length < 20) _eqnTyped.add(tok);
        return;
      }
    }
    switch ((modifier, key)) {
      case (_Modifier.none, CalcKey.del):
        if (_eqnTyped.isNotEmpty) _eqnTyped.removeLast();
      case (_Modifier.none, CalcKey.ac):
        _eqnTyped = [];
      case (_Modifier.none, CalcKey.up):
        _eqnTyped = [];
        if (_eqnIndex > 0) _eqnIndex--;
      case (_Modifier.none, CalcKey.down):
        _eqnTyped = [];
        if (_eqnIndex < names.length - 1) _eqnIndex++;
      case (_Modifier.none, CalcKey.equals):
        if (_eqnTyped.isNotEmpty) {
          try {
            final v = evaluateValue(_eqnTyped, EvalContext(ans: _ans));
            if (v.isComplex) throw const CalcError(CalcErrorKind.math);
            _eqnCoefficients[kind]![_eqnIndex] = v.dec;
          } on CalcError catch (e) {
            _eqnTyped = [];
            _showError(CalcError(e.kind));
            return;
          }
          _eqnTyped = [];
        }
        if (_eqnIndex < names.length - 1) {
          _eqnIndex++;
        } else {
          _solveEqn(kind);
        }
      default:
        break;
    }
  }

  void _solveEqn(String kind) {
    final c = _eqnCoefficients[kind]!;
    try {
      if (kind.startsWith('simul')) {
        final n = kind.endsWith('2') ? 2 : 3;
        _eqnSolutions = solveLinear([
          for (var r = 0; r < n; r++) c.sublist(r * (n + 1), (r + 1) * (n + 1)),
        ]);
      } else {
        _eqnSolutions = solvePolynomial(c);
      }
      _eqnSolution = 0;
      _complexPart = 0;
    } on CalcError catch (e) {
      _showError(CalcError(e.kind));
    }
  }

  // ------------------------------------------------------------------ BASE

  /// BASE-mode key meanings. Returns true when the key was handled here
  /// (including keys that do nothing in BASE mode).
  bool _pressBase(CalcKey key, _Modifier modifier) {
    if (modifier == _Modifier.none) {
      final newBase = switch (key) {
        CalcKey.square => 10,
        CalcKey.power => 16,
        CalcKey.log => 2,
        CalcKey.ln => 8,
        _ => null,
      };
      if (newBase != null) {
        _setBase(newBase);
        return true;
      }
      if (key == CalcKey.reciprocal) {
        _menu = _logicPages.first;
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
        _enter(hex);
        return true;
      }
      // Scientific functions, fractions, ENG, CONST … do nothing in BASE mode.
      const ignored = {
        CalcKey.sqrt,
        CalcKey.fraction,
        CalcKey.eng,
        CalcKey.constant,
        CalcKey.exp,
        CalcKey.calc,
        CalcKey.integrate,
        CalcKey.comma,
      };
      return ignored.contains(key);
    }
    if (modifier == _Modifier.shift) {
      // Only STO, INS, CLR, OFF-like keys keep their SHIFT meaning here.
      const allowed = {
        CalcKey.rcl,
        CalcKey.del,
        CalcKey.mode,
        CalcKey.mPlus,
        CalcKey.ac,
      };
      return !allowed.contains(key);
    }
    return false;
  }

  /// DEC/HEX/BIN/OCT: switches the number system; a shown result is converted.
  void _setBase(int base) {
    final v = _resultValue;
    if (_phase == _Phase.result && v != null) {
      try {
        baseOutput(v.dec, base);
      } on CalcError catch (e) {
        _base = base;
        _showError(e);
        return;
      }
    }
    _base = base;
  }

  // ------------------------------------------------------------------ SD / REG

  void _clearStats() {
    _stats.clear();
    _editLimit = null;
    _lastItem = null;
    _dataView = null;
  }

  void _selectRegression(RegressionType type) {
    _menu = null;
    if (_mode != CalcMode.reg) _setMode(CalcMode.reg);
    _stats.type = type;
    // Manual p.55: choosing a regression type clears A-F, X and Y.
    for (final name in ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y']) {
      _vars.remove(name);
    }
  }

  List<_Menu>? _statMenuPages(_Menu menu) {
    if (_statMenuTokens.containsKey(menu)) return [menu];
    final varPages = _stats.type == RegressionType.quad
        ? _quadVarPages
        : _regVarPages;
    for (final pages in [_regSumPages, varPages]) {
      if (pages.contains(menu)) return pages;
    }
    return null;
  }

  List<Tok> _statTokens(_Menu menu) {
    final direct = _statMenuTokens[menu];
    if (direct != null) return direct;
    final quad = _stats.type == RegressionType.quad;
    return switch ((
      _regSumPages.indexOf(menu),
      _regVarPages.indexOf(menu),
      _quadVarPages.indexOf(menu),
    )) {
      (0, _, _) => [Tok.statSumX2, Tok.statSumX, Tok.statN],
      (1, _, _) => [Tok.statSumY2, Tok.statSumY, Tok.statSumXY],
      (2, _, _) =>
        quad ? [Tok.statSumX3, Tok.statSumX2Y, Tok.statSumX4] : const [],
      (_, 0, _) ||
      (_, _, 0) => [Tok.statMeanX, Tok.statSigmaX, Tok.statSampleX],
      (_, 1, _) ||
      (_, _, 1) => [Tok.statMeanY, Tok.statSigmaY, Tok.statSampleY],
      (_, 2, _) => [Tok.regA, Tok.regB, Tok.regR],
      (_, _, 2) => [Tok.regA, Tok.regB, Tok.regC],
      (_, 3, _) => [Tok.estX, Tok.estY],
      (_, _, 3) => [Tok.estX1, Tok.estX2, Tok.estY],
      _ => const [],
    };
  }

  /// Maximum stored data items (then "Data Full").
  int get _capacity => _mode == CalcMode.sd ? 80 : 40;

  /// DT: registers x[;f] (SD) or x,y[;f] (REG); DT again repeats the last item.
  void _registerData() {
    if (_phase == _Phase.result && _tokens.isEmpty && _lastItem != null) {
      _addItem(_lastItem!);
      return;
    }
    if (_phase == _Phase.result &&
        _upperOverride == 'n=' &&
        _lastItem != null) {
      _addItem(_lastItem!);
      return;
    }
    if (_tokens.isEmpty) return;
    final StatItem item;
    try {
      item = _parseItem(_tokens);
    } on CalcError catch (e) {
      _showError(e);
      return;
    }
    if (_stats.items.length >= _capacity && _editLimit == null) {
      _pendingItem = item;
      _menu = _dataFullMenu;
      return;
    }
    _addItem(item);
  }

  StatItem _parseItem(List<Tok> tokens) {
    var depth = 0;
    int? comma, semi;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == Tok.openParen || t.kind == TokKind.function) depth++;
      if (t == Tok.closeParen) depth--;
      if (depth > 0) continue;
      if (t == Tok.comma && comma == null && semi == null) comma = i;
      if (t == Tok.freqSep) semi = i;
    }
    final reg = _mode == CalcMode.reg;
    if (reg != (comma != null)) {
      throw CalcError(CalcErrorKind.syntax, comma ?? tokens.length);
    }
    Dec part(int from, int to) {
      if (from >= to) throw CalcError(CalcErrorKind.syntax, from);
      try {
        final v = evaluateValue(tokens.sublist(from, to), _context());
        if (v.isComplex) throw const CalcError(CalcErrorKind.math);
        return v.dec;
      } on CalcError catch (e) {
        throw CalcError(e.kind, from + (e.position ?? 0));
      }
    }

    final end = semi ?? tokens.length;
    final x = part(0, comma ?? end);
    final y = comma == null ? null : part(comma + 1, end);
    final freq = semi == null ? Dec.one : part(semi + 1, tokens.length);
    if (freq <= Dec.zero) throw CalcError(CalcErrorKind.math, semi);
    return StatItem(x, y: y, freq: freq);
  }

  void _addItem(StatItem item) {
    _stats.add(item);
    _lastItem = item;
    _clearInput();
    _setResult(Value.dec(_stats.n));
    _upperOverride = 'n=';
    _phase = _Phase.result;
  }

  /// CL: deletes the item just entered (or the one shown in data view).
  void _deleteLastData() {
    if (_stats.isEmpty) return;
    _stats.items.removeLast();
    if (_editLimit != null && _editLimit! > _stats.items.length) {
      _editLimit = _stats.items.length;
    }
    _lastItem = null;
    _clearInput();
    _setResult(Value.dec(_stats.n));
    _upperOverride = 'n=';
    _phase = _Phase.result;
  }

  List<int> _fieldsOf(StatItem item) => [
    0,
    if (_mode == CalcMode.reg) 1,
    if (item.freq != Dec.one) 2,
  ];

  void _openDataView(bool up) {
    if (_editableItems == 0) return;
    if (_phase == _Phase.editing && _tokens.isNotEmpty) return;
    final last = _editableItems - 1;
    _dataView = up ? (last, 0) : (0, 0);
    _dataTyped = [];
  }

  /// Keys while a data item is shown. False: leave data view, handle normally.
  bool _pressDataView(CalcKey key) {
    final (index, field) = _dataView!;
    final modifier = _modifier;
    if (key == CalcKey.shift || key == CalcKey.alpha) return false;
    _modifier = _Modifier.none;
    if (key == CalcKey.ac) {
      _dataView = null;
      _clearInput();
      return true;
    }
    if (modifier == _Modifier.none) {
      final d = key.digit;
      final tok = d != null
          ? Tok.digits[d]
          : switch (key) {
              CalcKey.dot => Tok.point,
              CalcKey.exp => Tok.exp,
              CalcKey.negative => Tok.negative,
              _ => null,
            };
      if (tok != null) {
        if (_dataTyped.length < 20) _dataTyped.add(tok);
        return true;
      }
    }
    final item = _stats.items[index];
    switch ((modifier, key)) {
      case (_Modifier.none, CalcKey.del):
        if (_dataTyped.isNotEmpty) _dataTyped.removeLast();
      case (_Modifier.none, CalcKey.up || CalcKey.down):
        _dataTyped = [];
        _stepDataView(key == CalcKey.up ? -1 : 1);
      case (_Modifier.none, CalcKey.equals):
        if (_dataTyped.isEmpty) {
          _stepDataView(1);
          return true;
        }
        final v = _typedValue();
        if (v == null) return true;
        _stats.items[index] = switch (field) {
          0 => item.copyWith(x: v),
          1 => item.copyWith(y: v),
          _ => item.copyWith(freq: v),
        };
        _dataTyped = [];
        _stepDataView(1);
      case (_Modifier.none, CalcKey.mPlus):
        // DT: register the typed value as a new item, keep the old one.
        final v = _typedValue();
        if (v == null) return true;
        _dataView = null;
        _dataTyped = [];
        _addItem(switch (field) {
          0 => StatItem(v, y: item.y),
          1 => StatItem(item.x, y: v),
          _ => item.copyWith(freq: v),
        });
      case (_Modifier.shift, CalcKey.mPlus):
        _stats.items.removeAt(index);
        if (_editLimit != null) _editLimit = _editLimit! - 1;
        _dataTyped = [];
        if (_editableItems == 0) {
          _dataView = null;
          _clearInput();
        } else {
          _dataView = (index.clamp(0, _editableItems - 1), 0);
        }
      default:
        _dataView = null;
        _dataTyped = [];
        return false;
    }
    return true;
  }

  Dec? _typedValue() {
    if (_dataTyped.isEmpty) return null;
    try {
      final v = evaluateValue(_dataTyped, EvalContext(ans: _ans));
      if (v.isComplex) throw const CalcError(CalcErrorKind.math);
      if (_dataView!.$2 == 2 && v.dec <= Dec.zero) {
        throw const CalcError(CalcErrorKind.math);
      }
      return v.dec;
    } on CalcError catch (e) {
      _dataView = null;
      _dataTyped = [];
      _showError(CalcError(e.kind));
      return null;
    }
  }

  /// Moves through x, y, Freq fields and items (stops at both ends).
  void _stepDataView(int step) {
    final (index, field) = _dataView!;
    final fields = _fieldsOf(_stats.items[index]);
    final pos = fields.indexOf(field) + step;
    if (pos >= 0 && pos < fields.length) {
      _dataView = (index, fields[pos]);
      return;
    }
    final next = index + step;
    if (next < 0 || next >= _editableItems) return;
    final nextFields = _fieldsOf(_stats.items[next]);
    _dataView = (next, step > 0 ? nextFields.first : nextFields.last);
  }

  void _runStatement(int index) {
    var (start, end) = _statements[index];
    // CMPLX format commands (▶r∠θ, ▶a+bi) end a statement.
    bool? polar;
    while (end > start && _tokens[end - 1].kind == TokKind.formatCommand) {
      polar ??= _tokens[end - 1] == Tok.toPolar;
      end--;
    }
    try {
      final value = evaluateValue(_tokens.sublist(start, end), _context());
      _ans = value;
      _setResult(value);
      _polarCommand = polar;
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

  /// SHIFT =: append % and calculate.
  void _percent() {
    if (_phase == _Phase.result &&
        _tokens.isNotEmpty &&
        _tokens.last == Tok.percent) {
      return;
    }
    if (_phase != _Phase.editing || _tokens.isEmpty) return;
    _cursor = _tokens.length;
    _insert = false;
    _input(Tok.percent);
    _execute();
  }

  /// Conversion keys on a shown result: a b/c (fraction ↔ decimal),
  /// d/c (mixed ↔ improper), °′″ / ← (sexagesimal ↔ decimal), ENG / ←.
  void _convertResult(CalcKey key, bool shift) {
    final v = _resultValue;
    if (v == null) return;
    final shown = _result.mantissa;
    final showingFraction = shown.contains(fractionMark);
    final showingSexagesimal = shown.contains('°');
    switch (key) {
      case CalcKey.fraction when shift:
        if (showingFraction) _flipFractionStyle = !_flipFractionStyle;
      case CalcKey.fraction:
        _engExponent = null;
        _view = showingFraction ? ResultView.decimal : ResultView.fraction;
      case CalcKey.degMinSec when shift:
        _engExponent = null;
        _view = ResultView.sexagesimal;
      case CalcKey.degMinSec:
        if (showingSexagesimal) _view = ResultView.decimal;
      case CalcKey.eng:
        final current = _engExponent;
        _view = ResultView.decimal;
        if (current == null) {
          final natural = engExponentFor(v.dec);
          _engExponent = shift ? natural + 3 : natural;
        } else {
          _engExponent = shift ? current + 3 : current - 3;
        }
      default:
        break;
    }
  }

  // ------------------------------------------------------------------ history

  void _record(Value value) {
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
    _setResult(entry.value);
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
    _equation = null;
    _dataView = null;
    _menu = null;
    _codePrompt = null;
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
    'version': 2,
    'ans': _encode(_ans),
    'vars': {for (final e in _vars.entries) e.key: _encode(e.value)},
    'angle': _angle.name,
    'format': '${_format.mode.name}:${_format.digits}',
    'engOn': _settings.engOn,
    'polar': _settings.polarComplex,
    'mode': _mode.name,
    'regression': _stats.type.name,
    'base': _base,
    'eqn': {
      for (final e in _eqnCoefficients.entries)
        e.key: [for (final v in e.value) v.toString()],
    },
    'stats': [for (final i in _stats.items) '${i.x}|${i.y ?? ''}|${i.freq}'],
    'editLimit': _editLimit,
    'improper': _settings.improperFractions,
    'comma': _settings.decimalComma,
  };

  static String _encode(Value v) => v.isComplex
      ? 'c:${v.dec},${v.imag}'
      : v.frac != null
      ? 'f:${v.frac!.n}/${v.frac!.d}'
      : (v.isSexagesimal ? 's:${v.dec}' : v.dec.toString());

  static Value _decode(String s) {
    if (s.startsWith('c:')) {
      final [re, im] = s.substring(2).split(',');
      return Value.complex(Dec.parse(re), Dec.parse(im));
    }
    if (s.startsWith('f:')) {
      final [n, d] = s.substring(2).split('/');
      return Value.frac(Frac(BigInt.parse(n), BigInt.parse(d)));
    }
    if (s.startsWith('s:')) return Value.sexagesimal(Dec.parse(s.substring(2)));
    return Value.dec(Dec.parse(s));
  }

  /// Restores [saveState] output; silently ignores anything malformed.
  void restoreState(Map<String, Object?> state) {
    try {
      final ans = state['ans'];
      final vars = state['vars'];
      final angle = state['angle'];
      final format = state['format'];
      final newVars = <String, Value>{};
      if (vars is Map) {
        for (final MapEntry(:key, :value) in vars.entries) {
          if (key is String && value is String) newVars[key] = _decode(value);
        }
      }
      final newAns = ans is String ? _decode(ans) : _ans;
      final newAngle = angle is String
          ? AngleUnit.values.byName(angle)
          : _angle;
      final newFormat = format is String ? _parseFormat(format) : _format;
      _vars
        ..clear()
        ..addAll(newVars);
      _ans = newAns;
      _angle = newAngle;
      _settings = DisplaySettings(
        format: newFormat,
        engOn: state['engOn'] == true,
        improperFractions: state['improper'] == true,
        decimalComma: state['comma'] == true,
        polarComplex: state['polar'] == true,
      );
      final mode = state['mode'];
      if (mode is String) _mode = CalcMode.values.byName(mode);
      final eqn = state['eqn'];
      if (eqn is Map) {
        for (final MapEntry(:key, :value) in eqn.entries) {
          final target = _eqnCoefficients[key];
          if (target == null ||
              value is! List ||
              value.length != target.length) {
            continue;
          }
          for (var i = 0; i < target.length; i++) {
            target[i] = Dec.parse(value[i] as String);
          }
        }
      }
      final base = state['base'];
      if (base is int && const [10, 16, 2, 8].contains(base)) _base = base;
      final regression = state['regression'];
      if (regression is String) {
        _stats.type = RegressionType.values.byName(regression);
      }
      final stats = state['stats'];
      if (stats is List) {
        _stats.clear();
        for (final row in stats) {
          if (row is! String) continue;
          final [x, y, f] = row.split('|');
          _stats.add(
            StatItem(
              Dec.parse(x),
              y: y.isEmpty ? null : Dec.parse(y),
              freq: Dec.parse(f),
            ),
          );
        }
      }
      final limit = state['editLimit'];
      _editLimit = limit is int ? limit : null;
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
