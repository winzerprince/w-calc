import 'dart:math' as math;

import '../angle_unit.dart';
import '../format/number_format.dart';
import '../input/token.dart';
import '../number/dec.dart';
import '../number/functions.dart';

/// Priority levels from the device's "calculation priority sequence".
/// Lower number = binds tighter. Equal levels evaluate left to right.
abstract final class Priority {
  /// Powers and roots: x^y, ˣ√.
  static const power = 3;

  /// Implied multiplication before π, e, memory or variable names (2π, 3A, 2Ans).
  static const impliedOperand = 5;

  /// Type B functions: (−), √, sin, log, ...
  static const prefix = 6;

  /// Implied multiplication before Type B functions and parentheses (2√3, 2(3)).
  /// TODO(device): parentheses assumed here (6÷2(1+2) = 1); see behaviour-notes #5.
  static const impliedFunction = 7;

  /// nPr, nCr.
  static const permutation = 8;

  static const multiplyDivide = 10;
  static const addSubtract = 11;
}

/// Numeric stack depth.
const int numericStackSize = 10;

/// Command (operator) stack depth.
const int commandStackSize = 24;

/// Everything an expression may read besides its tokens.
class EvalContext {
  EvalContext({
    required this.ans,
    this.angle = AngleUnit.deg,
    this.format = const DisplayFormat.norm1(),
    this.variables = const {},
    math.Random? random,
  }) : random = random ?? math.Random();

  /// Values of A–F, M, X, Y by name; missing names read as 0.
  final Map<String, Dec> variables;

  final Dec ans;
  final AngleUnit angle;

  /// Display setting, used by Rnd.
  final DisplayFormat format;
  final math.Random random;
}

/// Evaluates one expression. Throws [CalcError] (with token position).
Dec evaluate(List<Tok> tokens, {required Dec ans, EvalContext? context}) =>
    _Evaluator(tokens, context ?? EvalContext(ans: ans)).run();

enum _OpType { paren, binary, prefix }

class _Op {
  const _Op(this.type, this.priority, this.pos, [this.apply2, this.apply1]);

  final _OpType type;
  final int priority;
  final int pos;
  final Dec Function(Dec, Dec)? apply2;
  final Dec Function(Dec)? apply1;
}

Dec _mul(Dec a, Dec b) => a * b;

/// Rnd: round to what the display would show.
Dec roundForDisplay(Dec x, DisplayFormat f) => switch (f.mode) {
  DisplayMode.norm => x.roundSignificant(displayDigits),
  DisplayMode.fix => x.roundDecimals(f.digits),
  DisplayMode.sci => x.roundSignificant(
    f.digits == 0 ? displayDigits : f.digits,
  ),
};

class _Evaluator {
  _Evaluator(this.tokens, this.ctx);

  final List<Tok> tokens;
  final EvalContext ctx;
  final List<Dec> values = [];
  final List<_Op> ops = [];

  Never _syntax(int pos) => throw CalcError(CalcErrorKind.syntax, pos);

  Dec run() {
    var expectOperand = true;
    var i = 0;
    while (i < tokens.length) {
      final tok = tokens[i];
      switch (tok.kind) {
        case TokKind.digit || TokKind.point || TokKind.exp:
          if (!expectOperand) _syntax(i);
          i = _literal(i);
          expectOperand = false;
          continue;
        case TokKind.operand || TokKind.constant || TokKind.variable:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedOperand, i, _mul));
          }
          _pushValue(_operandValue(tok), i);
          expectOperand = false;
        case TokKind.openParen:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          _pushOp(_Op(_OpType.paren, 0, i));
          expectOperand = true;
        case TokKind.prefix:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          _pushOp(
            _Op(_OpType.prefix, Priority.prefix, i, null, _prefixFn(tok)),
          );
          expectOperand = true;
        case TokKind.binary:
          if (expectOperand) _syntax(i);
          _pushBinary(_binaryOp(tok, i));
          expectOperand = true;
        case TokKind.postfix:
          // Type A functions bind tighter than anything but parenthesised
          // functions, so they apply to the value just completed.
          if (expectOperand) _syntax(i);
          _guard(i, () => values.add(_postfixFn(tok)(values.removeLast())));
        case TokKind.separator:
          _syntax(i); // Multi-statements are split before evaluation.
        case TokKind.closeParen:
          if (expectOperand) _syntax(i);
          while (ops.isNotEmpty && ops.last.type != _OpType.paren) {
            _apply(ops.removeLast());
          }
          if (ops.isEmpty) _syntax(i);
          ops.removeLast();
          expectOperand = false;
      }
      i++;
    }
    if (expectOperand) _syntax(tokens.length);
    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op.type != _OpType.paren) {
        _apply(op); // Missing ")" at the end is allowed.
      }
    }
    return values.single;
  }

  Dec _operandValue(Tok tok) => switch (tok) {
    Tok.ans => ctx.ans,
    Tok.pi => piConstant,
    Tok.e => eConstant,
    Tok.ran => Dec(BigInt.from(ctx.random.nextInt(1000)), -3),
    _ when tok.kind == TokKind.variable => ctx.variables[tok.text] ?? Dec.zero,
    _ => throw ArgumentError('not an operand: $tok'),
  };

  /// Parses a number literal starting at [start]; returns index after it.
  int _literal(int start) {
    final mantissa = StringBuffer();
    var i = start;
    var sawPoint = false;
    while (i < tokens.length &&
        (tokens[i].kind == TokKind.digit || tokens[i] == Tok.point)) {
      if (tokens[i] == Tok.point) {
        if (sawPoint) _syntax(i);
        sawPoint = true;
      }
      mantissa.write(tokens[i].text);
      i++;
    }
    var exponent = '';
    if (i < tokens.length && tokens[i] == Tok.exp) {
      i++;
      if (i < tokens.length && tokens[i] == Tok.negative) {
        exponent = '-';
        i++;
      }
      var count = 0;
      while (i < tokens.length && tokens[i].kind == TokKind.digit) {
        if (++count > 2) _syntax(i);
        exponent += tokens[i].text;
        i++;
      }
      if (count == 0) _syntax(i);
      if (i < tokens.length && tokens[i] == Tok.point) _syntax(i);
    }
    var m = mantissa.toString();
    if (m.isEmpty) m = '1'; // EXP pressed first: 1E…
    if (m == '.') _syntax(start);
    _guard(start, () {
      _pushValue(Dec.parse(exponent.isEmpty ? m : '${m}e$exponent'), start);
    });
    return i;
  }

  void _guard(int pos, void Function() body) {
    try {
      body();
    } on CalcError catch (e) {
      throw e.at(pos);
    }
  }

  void _pushValue(Dec v, int pos) {
    if (values.length >= numericStackSize) {
      throw CalcError(CalcErrorKind.stack, pos);
    }
    values.add(v);
  }

  void _pushOp(_Op op) {
    if (ops.length >= commandStackSize) {
      throw CalcError(CalcErrorKind.stack, op.pos);
    }
    ops.add(op);
  }

  void _pushBinary(_Op op) {
    while (ops.isNotEmpty &&
        ops.last.type != _OpType.paren &&
        ops.last.priority <= op.priority) {
      _apply(ops.removeLast());
    }
    _pushOp(op);
  }

  void _apply(_Op op) {
    _guard(op.pos, () {
      if (op.type == _OpType.prefix) {
        values.add(op.apply1!(values.removeLast()));
      } else {
        final b = values.removeLast();
        final a = values.removeLast();
        values.add(op.apply2!(a, b));
      }
    });
  }

  Dec Function(Dec) _prefixFn(Tok tok) {
    final u = ctx.angle;
    return switch (tok) {
      Tok.negative => (a) => -a,
      Tok.sin => (a) => sinDec(a, u),
      Tok.cos => (a) => cosDec(a, u),
      Tok.tan => (a) => tanDec(a, u),
      Tok.asin => (a) => asinDec(a, u),
      Tok.acos => (a) => acosDec(a, u),
      Tok.atan => (a) => atanDec(a, u),
      Tok.sinh => sinhDec,
      Tok.cosh => coshDec,
      Tok.tanh => tanhDec,
      Tok.asinh => asinhDec,
      Tok.acosh => acoshDec,
      Tok.atanh => atanhDec,
      Tok.log => logDec,
      Tok.ln => lnDec,
      Tok.tenPow => tenPowDec,
      Tok.ePow => expDec,
      Tok.sqrt => sqrtDec,
      Tok.cbrt => cbrtDec,
      Tok.rnd => (a) => roundForDisplay(a, ctx.format),
      _ => throw ArgumentError('not a prefix token: $tok'),
    };
  }

  Dec Function(Dec) _postfixFn(Tok tok) {
    final u = ctx.angle;
    return switch (tok) {
      Tok.square => squareDec,
      Tok.cube => cubeDec,
      Tok.reciprocal => reciprocalDec,
      Tok.factorial => factorialDec,
      Tok.degMark => (a) => convertAngle(a, AngleUnit.deg, u),
      Tok.radMark => (a) => convertAngle(a, AngleUnit.rad, u),
      Tok.graMark => (a) => convertAngle(a, AngleUnit.gra, u),
      _ => throw ArgumentError('not a postfix token: $tok'),
    };
  }

  static _Op _binaryOp(Tok tok, int pos) => switch (tok) {
    Tok.add => _Op(_OpType.binary, Priority.addSubtract, pos, (a, b) => a + b),
    Tok.subtract => _Op(
      _OpType.binary,
      Priority.addSubtract,
      pos,
      (a, b) => a - b,
    ),
    Tok.multiply => _Op(_OpType.binary, Priority.multiplyDivide, pos, _mul),
    Tok.divide => _Op(
      _OpType.binary,
      Priority.multiplyDivide,
      pos,
      (a, b) => a / b,
    ),
    Tok.power => _Op(_OpType.binary, Priority.power, pos, powDec),
    Tok.xRoot => _Op(_OpType.binary, Priority.power, pos, xRootDec),
    Tok.nPr => _Op(_OpType.binary, Priority.permutation, pos, permutationDec),
    Tok.nCr => _Op(_OpType.binary, Priority.permutation, pos, combinationDec),
    _ => throw ArgumentError('not a binary token: $tok'),
  };
}
