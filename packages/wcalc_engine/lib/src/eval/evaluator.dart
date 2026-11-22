import 'dart:math' as math;

import '../angle_unit.dart';
import '../format/number_format.dart';
import '../input/token.dart';
import '../number/dec.dart';
import '../number/frac.dart';
import '../number/functions.dart';
import '../number/value.dart';

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
    Value? ans,
    this.angle = AngleUnit.deg,
    this.format = const DisplayFormat.norm1(),
    this.variables = const {},
    this.improperFractions = false,
    math.Random? random,
  }) : ans = ans ?? Value.zero,
       random = random ?? math.Random();

  final Value ans;
  final AngleUnit angle;

  /// Display setting, used by Rnd.
  final DisplayFormat format;

  /// Values of A–F, M, X, Y by name; missing names read as 0.
  final Map<String, Value> variables;

  /// d/c display setting: mixed-fraction input is a Syntax ERROR.
  final bool improperFractions;
  final math.Random random;
}

/// Evaluates one expression to a decimal (convenience for tests).
Dec evaluate(List<Tok> tokens, {required Dec ans, EvalContext? context}) =>
    evaluateValue(tokens, context ?? EvalContext(ans: Value.dec(ans))).dec;

/// Evaluates one expression. Throws [CalcError] (with token position).
/// Expressions ending in `%` (optionally followed by + or −) use the percent
/// rules from the manual.
Value evaluateValue(List<Tok> tokens, EvalContext ctx) {
  final p = tokens.indexOf(Tok.percent);
  if (p < 0) return _Evaluator(tokens, ctx).run();
  return _percent(tokens, p, ctx);
}

/// Percent calculations (manual p.20-22), split at the last top-level operator:
/// A×B% = A·B/100, A÷B% = A/B·100, A+B% = (A+B)/B·100, A−B% = (A−B)/B·100,
/// A×B%+ = A + A·B/100, A×B%− = A − A·B/100.
Value _percent(List<Tok> tokens, int p, EvalContext ctx) {
  final tail = tokens.sublist(p + 1);
  if (tail.length > 1 ||
      (tail.isNotEmpty &&
          tail.single != Tok.add &&
          tail.single != Tok.subtract)) {
    throw CalcError(CalcErrorKind.syntax, p + 1);
  }
  final body = tokens.sublist(0, p);
  var depth = 0, split = -1;
  for (var i = 0; i < body.length; i++) {
    final t = body[i];
    if (t == Tok.openParen) depth++;
    if (t == Tok.closeParen) depth--;
    if (depth == 0 &&
        i > 0 &&
        (t == Tok.add ||
            t == Tok.subtract ||
            t == Tok.multiply ||
            t == Tok.divide)) {
      split = i;
    }
  }
  final hundred = Dec.fromInt(100);
  if (split < 0) {
    final b = _Evaluator(body, ctx).run().dec;
    return Value.dec(b / hundred);
  }
  final a = _Evaluator(body.sublist(0, split), ctx).run().dec;
  final b = _guarded(
    split + 1,
    () => _Evaluator(body.sublist(split + 1), ctx).run().dec,
  );
  try {
    final op = body[split];
    final percent = switch (op) {
      Tok.multiply => a * b / hundred,
      Tok.divide => a / b * hundred,
      Tok.add => (a + b) / b * hundred,
      _ => (a - b) / b * hundred,
    };
    if (tail.isEmpty) return Value.dec(percent);
    if (op != Tok.multiply) throw CalcError(CalcErrorKind.syntax, p + 1);
    return Value.dec(tail.single == Tok.add ? a + percent : a - percent);
  } on CalcError catch (e) {
    throw e.at(p);
  }
}

T _guarded<T>(int offset, T Function() body) {
  try {
    return body();
  } on CalcError catch (e) {
    throw CalcError(e.kind, offset + (e.position ?? 0));
  }
}

enum _OpType { paren, binary, prefix }

class _Op {
  const _Op(this.type, this.priority, this.pos, [this.apply2, this.apply1]);

  final _OpType type;
  final int priority;
  final int pos;
  final Value Function(Value, Value)? apply2;
  final Value Function(Value)? apply1;
}

Value _mul(Value a, Value b) => a * b;

/// Wraps a decimal function as a value function.
Value Function(Value) _d1(Dec Function(Dec) f) =>
    (a) => Value.dec(f(a.dec));
Value Function(Value, Value) _d2(Dec Function(Dec, Dec) f) =>
    (a, b) => Value.dec(f(a.dec, b.dec));

/// Rnd: round to what the display would show.
Dec roundForDisplay(Dec x, DisplayFormat f) => switch (f.mode) {
  DisplayMode.norm => x.roundSignificant(displayDigits),
  DisplayMode.fix => x.roundDecimals(f.digits),
  DisplayMode.sci => x.roundSignificant(
    f.digits == 0 ? displayDigits : f.digits,
  ),
};

/// x^y keeping fractions exact for integer exponents.
Value _power(Value a, Value b) {
  if (a.frac != null && b.dec.isInteger && b.dec.abs() <= Dec.fromInt(1000)) {
    return a.powInt(b.dec.toInt())!;
  }
  return Value.dec(powDec(a.dec, b.dec));
}

const _engExponents = {
  Tok.engT: 12,
  Tok.engG: 9,
  Tok.engMega: 6,
  Tok.engKilo: 3,
  Tok.engMilli: -3,
  Tok.engMicro: -6,
  Tok.engNano: -9,
  Tok.engPico: -12,
  Tok.engFemto: -15,
};

class _Evaluator {
  _Evaluator(this.tokens, this.ctx);

  final List<Tok> tokens;
  final EvalContext ctx;
  final List<Value> values = [];
  final List<_Op> ops = [];

  Never _syntax(int pos) => throw CalcError(CalcErrorKind.syntax, pos);

  Value run() {
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
        case TokKind.separator || TokKind.literalMark || TokKind.percent:
          _syntax(i); // Handled by literal parsing / the calculator.
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

  Value _operandValue(Tok tok) => switch (tok) {
    Tok.ans => ctx.ans,
    Tok.pi => Value.dec(piConstant),
    Tok.e => Value.dec(eConstant),
    Tok.ran => Value.dec(Dec(BigInt.from(ctx.random.nextInt(1000)), -3)),
    _ when tok.kind == TokKind.variable =>
      ctx.variables[tok.text] ?? Value.zero,
    _ => throw ArgumentError('not an operand: $tok'),
  };

  /// Parses one plain number at [start]: (value, next index, integer digits only).
  (Dec, int, bool) _number(int start) {
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
    if (m.isEmpty) {
      if (exponent.isEmpty) _syntax(start);
      m = '1'; // EXP pressed first: 1E…
    }
    if (m == '.') _syntax(start);
    late Dec value;
    _guard(
      start,
      () => value = Dec.parse(exponent.isEmpty ? m : '${m}e$exponent'),
    );
    return (value, i, !sawPoint && exponent.isEmpty);
  }

  /// Parses a literal: number, fraction a┘b[┘c], or sexagesimal d°[m°[s°]].
  int _literal(int start) {
    var (value, i, integer) = _number(start);
    if (i < tokens.length && tokens[i] == Tok.fracSep) {
      final parts = [value];
      while (i < tokens.length && tokens[i] == Tok.fracSep) {
        if (!integer || parts.length == 3) _syntax(i);
        final (next, j, nextInteger) = _number(i + 1);
        parts.add(next);
        integer = nextInteger;
        i = j;
      }
      if (!integer) _syntax(i);
      if (parts.length == 3 && ctx.improperFractions) _syntax(start);
      BigInt big(Dec d) => BigInt.parse(d.toString());
      _guard(start, () {
        final f = parts.length == 2
            ? Frac(big(parts[0]), big(parts[1]))
            : Frac.fromInt(big(parts[0])) + Frac(big(parts[1]), big(parts[2]));
        _pushValue(Value.frac(f), start);
      });
      return i;
    }
    if (i < tokens.length && tokens[i] == Tok.dms) {
      final parts = [value];
      i++;
      while (parts.length < 3 &&
          i < tokens.length &&
          (tokens[i].kind == TokKind.digit || tokens[i] == Tok.point)) {
        final (next, j, _) = _number(i);
        parts.add(next);
        i = j;
        if (i < tokens.length && tokens[i] == Tok.dms) {
          i++;
        } else {
          break;
        }
      }
      if (i < tokens.length && tokens[i] == Tok.dms) _syntax(i);
      _guard(start, () {
        var total = parts[0];
        if (parts.length > 1) total += parts[1] / Dec.fromInt(60);
        if (parts.length > 2) total += parts[2] / Dec.fromInt(3600);
        _pushValue(Value.sexagesimal(total), start);
      });
      return i;
    }
    _pushValue(Value.dec(value), start);
    return i;
  }

  void _guard(int pos, void Function() body) {
    try {
      body();
    } on CalcError catch (e) {
      throw e.at(pos);
    }
  }

  void _pushValue(Value v, int pos) {
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

  Value Function(Value) _prefixFn(Tok tok) {
    final u = ctx.angle;
    return switch (tok) {
      Tok.negative => (a) => -a,
      Tok.sin => _d1((a) => sinDec(a, u)),
      Tok.cos => _d1((a) => cosDec(a, u)),
      Tok.tan => _d1((a) => tanDec(a, u)),
      Tok.asin => _d1((a) => asinDec(a, u)),
      Tok.acos => _d1((a) => acosDec(a, u)),
      Tok.atan => _d1((a) => atanDec(a, u)),
      Tok.sinh => _d1(sinhDec),
      Tok.cosh => _d1(coshDec),
      Tok.tanh => _d1(tanhDec),
      Tok.asinh => _d1(asinhDec),
      Tok.acosh => _d1(acoshDec),
      Tok.atanh => _d1(atanhDec),
      Tok.log => _d1(logDec),
      Tok.ln => _d1(lnDec),
      Tok.tenPow => _d1(tenPowDec),
      Tok.ePow => _d1(expDec),
      Tok.sqrt => _d1(sqrtDec),
      Tok.cbrt => _d1(cbrtDec),
      Tok.rnd => _d1((a) => roundForDisplay(a, ctx.format)),
      _ => throw ArgumentError('not a prefix token: $tok'),
    };
  }

  Value Function(Value) _postfixFn(Tok tok) {
    final u = ctx.angle;
    final eng = _engExponents[tok];
    if (eng != null) return _d1((a) => a * Dec(BigInt.one, eng));
    return switch (tok) {
      Tok.square => (a) => a.powInt(2) ?? Value.dec(squareDec(a.dec)),
      Tok.cube => (a) => a.powInt(3) ?? Value.dec(cubeDec(a.dec)),
      Tok.reciprocal => (a) => a.powInt(-1) ?? Value.dec(reciprocalDec(a.dec)),
      Tok.factorial => _d1(factorialDec),
      Tok.degMark => _d1((a) => convertAngle(a, AngleUnit.deg, u)),
      Tok.radMark => _d1((a) => convertAngle(a, AngleUnit.rad, u)),
      Tok.graMark => _d1((a) => convertAngle(a, AngleUnit.gra, u)),
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
    Tok.power => _Op(_OpType.binary, Priority.power, pos, _power),
    Tok.xRoot => _Op(_OpType.binary, Priority.power, pos, _d2(xRootDec)),
    Tok.nPr => _Op(
      _OpType.binary,
      Priority.permutation,
      pos,
      _d2(permutationDec),
    ),
    Tok.nCr => _Op(
      _OpType.binary,
      Priority.permutation,
      pos,
      _d2(combinationDec),
    ),
    _ => throw ArgumentError('not a binary token: $tok'),
  };
}
