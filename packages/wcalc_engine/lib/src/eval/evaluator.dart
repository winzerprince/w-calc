import 'dart:math' as math;

import '../angle_unit.dart';
import '../format/number_format.dart';
import '../input/token.dart';
import '../number/dec.dart';
import '../number/constants.dart';
import '../number/frac.dart';
import '../number/functions.dart';
import '../number/linalg.dart';
import '../number/surd.dart';
import '../number/value.dart';
import '../number/wide.dart';
import '../stats/stats.dart';

/// Priority levels from the device's "calculation priority sequence".
/// Lower number = binds tighter. Equal levels evaluate left to right.
abstract final class Priority {
  /// Powers and roots: x^y, ˣ√.
  static const power = 3;

  /// Implied multiplication before π, e, memory or variable names (2π, 3A, 2Ans).
  static const impliedOperand = 5;

  /// Fraction bar (textbook display): binds tighter than (−).
  static const fraction = 4;

  /// Type B functions: (−), √, sin, log, ...
  static const prefix = 6;

  /// Implied multiplication before Type B functions and parentheses (2√3, 2(3)).
  /// TODO(device): parentheses assumed here (6÷2(1+2) = 1); see behaviour-notes #5.
  static const impliedFunction = 7;

  /// nPr, nCr.
  static const permutation = 8;

  /// Vector dot product.
  static const dotProduct = 9;

  static const multiplyDivide = 10;
  static const addSubtract = 11;

  /// BASE logic: and; or, xor, xnor.
  static const logicAnd = 12;
  static const logicOr = 13;
}

/// Numeric stack depth.
const int numericStackSize = 10;

/// Matrices / vectors that may be pending at once (MAT/VCT stack).
const int linearStackSize = 2;

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
    this.store,
    this.stats,
    this.base,
    this.linear = const {},
    this.polRecVars = const ('E', 'F'),
    this.exactForms = false,
    this.functionParens = false,
    this.wideBase = false,
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

  /// Statistical memory in SD/REG mode (null elsewhere).
  final StatData? stats;

  /// BASE mode number system (10, 16, 2, 8), or null outside BASE mode.
  final int? base;

  /// MAT / VCT variables by name (MatA … VctAns); missing = not dimensioned.
  final Map<String, Value> linear;

  /// Textbook-display models: decimals, √ and π stay exact where possible
  /// (results can then be shown as fractions, √ forms and π forms).
  final bool exactForms;

  /// Textbook models: a function's bracket group (sin(…), √(…)) is applied
  /// as soon as it closes.
  final bool functionParens;

  /// Textbook models: 16-bit binary, 32-bit octal (see [wideBaseBits]).
  final bool wideBase;

  /// Variables Pol/Rec write their two results to (E, F on two-line models;
  /// X, Y on textbook-display models).
  final (String, String) polRecVars;

  /// Receives values functions write to variables (Pol/Rec → E, F).
  final void Function(String name, Value value)? store;
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
  _Op(
    this.type,
    this.priority,
    this.pos, [
    this.apply2,
    this.apply1,
    this.function,
    this.valueBase = 0,
  ]);

  final _OpType type;
  final int priority;
  final int pos;
  final Value Function(Value, Value)? apply2;
  final Value Function(Value)? apply1;

  /// For parentheses opened by a function token (Pol(, Rec( …).
  final Tok? function;

  /// Values below this index belong to the enclosing expression.
  final int valueBase;
}

Value _mul(Value a, Value b) => a * b;

/// Wraps a real function as a value function; complex arguments are a
/// Math ERROR (the device only has arithmetic, Abs, arg, Conjg for them).
Value Function(Value) _d1(Dec Function(Dec) f) => (a) {
  if (a.isComplex || a.isLinear) throw const CalcError(CalcErrorKind.math);
  return Value.dec(f(a.dec));
};
Value Function(Value, Value) _d2(Dec Function(Dec, Dec) f) => (a, b) {
  if (a.isComplex || b.isComplex || a.isLinear || b.isLinear) {
    throw const CalcError(CalcErrorKind.math);
  }
  return Value.dec(f(a.dec, b.dec));
};

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
  if (a.isComplex || b.isComplex) {
    if (b.isComplex || !b.dec.isInteger || b.dec.abs() > Dec.fromInt(1000)) {
      throw const CalcError(CalcErrorKind.math);
    }
    return a.powInt(b.dec.toInt())!;
  }
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
        case TokKind.digit ||
                TokKind.point ||
                TokKind.exp ||
                TokKind.hexDigit ||
                TokKind.basePrefix
            when ctx.base != null:
          if (!expectOperand) _syntax(i);
          i = _baseLiteral(i);
          expectOperand = false;
          continue;
        case TokKind.hexDigit || TokKind.basePrefix:
          _syntax(i);
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
        case TokKind.function
            when tok == Tok.integral ||
                tok == Tok.derivative ||
                tok == Tok.sigma:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          i = _calculus(i);
          expectOperand = false;
          continue;
        case TokKind.function:
          if (!expectOperand) {
            _pushBinary(_Op(_OpType.binary, Priority.impliedFunction, i, _mul));
          }
          _pushOp(_Op(_OpType.paren, 0, i, null, null, tok, values.length));
          expectOperand = true;
        case TokKind.comma:
          if (expectOperand) _syntax(i);
          while (ops.isNotEmpty && ops.last.type != _OpType.paren) {
            _apply(ops.removeLast());
          }
          if (ops.isEmpty || ops.last.function == null) _syntax(i);
          expectOperand = true;
        case TokKind.separator ||
            TokKind.literalMark ||
            TokKind.percent ||
            TokKind.equation ||
            TokKind.formatCommand ||
            TokKind.dataSep:
          _syntax(i); // Handled by literal parsing / the calculator.
        case TokKind.closeParen:
          if (expectOperand) _syntax(i);
          while (ops.isNotEmpty && ops.last.type != _OpType.paren) {
            _apply(ops.removeLast());
          }
          if (ops.isEmpty) _syntax(i);
          final closed = ops.removeLast();
          _closeParen(closed, i);
          // Textbook models: f( … ) is one unit, so sin(30)A = sin(30)·A.
          if (ctx.functionParens &&
              ops.isNotEmpty &&
              ops.last.type == _OpType.prefix &&
              ops.last.pos == closed.pos - 1) {
            _apply(ops.removeLast());
          }
          expectOperand = false;
      }
      i++;
    }
    if (expectOperand) _syntax(tokens.length);
    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      // Missing ")" at the end is allowed.
      if (op.type == _OpType.paren) {
        _closeParen(op, tokens.length);
      } else {
        _apply(op);
      }
    }
    return values.single;
  }

  /// ∫( f, a, b[, n] ) and d/dx( f, a[, Δx] ): the first argument is an
  /// expression in X evaluated repeatedly. Returns the index after `)`.
  int _calculus(int start) {
    final args = <(int, int)>[]; // token ranges
    var depth = 0, argStart = start + 1, end = tokens.length;
    for (var j = start + 1; j < tokens.length; j++) {
      final t = tokens[j];
      if (t == Tok.openParen || t.kind == TokKind.function) depth++;
      if (t == Tok.closeParen) {
        if (depth == 0) {
          end = j;
          break;
        }
        depth--;
      }
      if (t == Tok.comma && depth == 0) {
        args.add((argStart, j));
        argStart = j + 1;
      }
    }
    args.add((argStart, end));
    final integral = tokens[start] == Tok.integral;
    final sigma = tokens[start] == Tok.sigma;
    final (minArgs, maxArgs) = integral
        ? (3, 4)
        : sigma
        ? (3, 3)
        : (2, 3);
    if (args.length < minArgs || args.length > maxArgs) _syntax(end);
    for (final (a, b) in args) {
      if (a == b) _syntax(a);
    }

    Dec number(int k) {
      final (a, b) = args[k];
      return _guarded(a, () => _Evaluator(tokens.sublist(a, b), ctx).run().dec);
    }

    final (fa, fb) = args[0];
    final body = tokens.sublist(fa, fb);
    Wide f(Wide x) => Wide.fromDec(
      _guarded(
        fa,
        () => _Evaluator(
          body,
          EvalContext(
            ans: ctx.ans,
            angle: ctx.angle,
            format: ctx.format,
            variables: {...ctx.variables, 'X': Value.dec(x.toDec())},
            improperFractions: ctx.improperFractions,
            random: ctx.random,
            polRecVars: ctx.polRecVars,
            exactForms: ctx.exactForms,
            functionParens: ctx.functionParens,
          ),
        ).run().dec,
      ),
    );

    if (sigma) {
      final a = number(1), b = number(2);
      _pushValue(_guarded(start, () => _sum(fa, body, a, b)), start);
      return end < tokens.length ? end + 1 : end;
    }

    late Dec result;
    if (integral) {
      final a = number(1), b = number(2);
      int? n;
      if (args.length == 4) {
        final nd = number(3);
        if (!nd.isInteger || nd < Dec.one || nd > Dec.fromInt(9)) {
          throw CalcError(CalcErrorKind.math, args[3].$1);
        }
        n = nd.toInt();
      }
      result = _guarded(
        start,
        () => _simpson(f, Wide.fromDec(a), Wide.fromDec(b), n),
      );
    } else {
      final a = number(1);
      final h = args.length == 3 ? number(2) : null;
      result = _guarded(start, () => _derivative(f, Wide.fromDec(a), h));
    }
    _pushValue(Value.dec(result), start);
    return end < tokens.length ? end + 1 : end;
  }

  /// Σ(f, a, b) = f(a) + f(a+1) + … + f(b); fractions stay exact.
  Value _sum(int pos, List<Tok> body, Dec a, Dec b) {
    final limit = Dec.parse('1e10');
    if (!a.isInteger ||
        !b.isInteger ||
        b < a ||
        a.abs() > limit ||
        b.abs() > limit) {
      throw const CalcError(CalcErrorKind.math);
    }
    var total = Value.zero;
    for (var x = a; x <= b; x = x + Dec.one) {
      final term = _Evaluator(
        body,
        EvalContext(
          ans: ctx.ans,
          angle: ctx.angle,
          format: ctx.format,
          variables: {...ctx.variables, 'X': Value.dec(x)},
          improperFractions: ctx.improperFractions,
          random: ctx.random,
          polRecVars: ctx.polRecVars,
          exactForms: ctx.exactForms,
          functionParens: ctx.functionParens,
        ),
      ).run();
      total = total + term;
    }
    return total;
  }

  /// Closes a parenthesis; for a function, applies it to its arguments.
  void _closeParen(_Op paren, int pos) {
    final f = paren.function;
    if (f == null) return;
    final args = values.sublist(paren.valueBase);
    values.removeRange(paren.valueBase, values.length);
    _guard(paren.pos, () => values.add(_callFunction(f, args, pos)));
  }

  Value _callFunction(Tok f, List<Value> args, int pos) {
    switch (f) {
      case Tok.pol || Tok.rec:
        if (args.length != 2) _syntax(pos);
        final (a, b) = f == Tok.pol
            ? polarDec(args[0].dec, args[1].dec, ctx.angle)
            : rectangularDec(args[0].dec, args[1].dec, ctx.angle);
        ctx.store?.call(ctx.polRecVars.$1, Value.dec(a));
        ctx.store?.call(ctx.polRecVars.$2, Value.dec(b));
        return Value.dec(a);
      case Tok.distP || Tok.distQ || Tok.distR:
        if (args.length != 1) _syntax(pos);
        if (args.single.isComplex) throw const CalcError(CalcErrorKind.math);
        final t = args.single.dec;
        return Value.dec(switch (f) {
          Tok.distP => normalP(t),
          Tok.distQ => normalQ(t),
          _ => normalR(t),
        });
      case Tok.logBase:
        // log(x) is base 10; log(a, x) is base a.
        if (args.isEmpty || args.length > 2) _syntax(pos);
        if (args.any((a) => a.isComplex)) {
          throw const CalcError(CalcErrorKind.math);
        }
        if (args.length == 1) return Value.dec(logDec(args.single.dec));
        return Value.dec(logBaseDec(args[0].dec, args[1].dec));
      case Tok.ranInt:
        if (args.length != 2) _syntax(pos);
        final lo = args[0].dec, hi = args[1].dec;
        if (!lo.isInteger || !hi.isInteger || hi < lo) {
          throw const CalcError(CalcErrorKind.math);
        }
        final span = (hi - lo).toInt() + 1;
        if (span > 10000000000) throw const CalcError(CalcErrorKind.math);
        return Value.dec(lo + Dec.fromInt(ctx.random.nextInt(span)));
      default:
        throw ArgumentError('not a function: $f');
    }
  }

  Value _operandValue(Tok tok) => switch (tok) {
    Tok.ans => ctx.ans,
    Tok.pi =>
      ctx.exactForms
          ? Value.pi(Frac.fromInt(BigInt.one))
          : Value.dec(piConstant),
    Tok.e => Value.dec(eConstant),
    Tok.imagUnit => Value.imaginaryUnit,
    _ when tok.name.startsWith('mat') || tok.name.startsWith('vct') =>
      ctx.linear[tok.text] ?? (throw const CalcError(CalcErrorKind.dim)),
    _ when tok.name.startsWith('stat') || tok.name.startsWith('reg') =>
      Value.dec(_statValue(tok)),
    Tok.ran => Value.dec(Dec(BigInt.from(ctx.random.nextInt(1000)), -3)),
    _ when tok.name.startsWith('const') => Value.dec(
      constantValues[Tok.constants.indexOf(tok)],
    ),
    _ when tok.kind == TokKind.variable =>
      ctx.variables[tok.text] ?? Value.zero,
    _ => throw ArgumentError('not an operand: $tok'),
  };

  Dec _statValue(Tok tok) {
    final s = ctx.stats ?? (throw const CalcError(CalcErrorKind.math));
    return switch (tok) {
      Tok.statSumX2 => s.sumX2,
      Tok.statSumX => s.sumX,
      Tok.statN => s.n,
      Tok.statSumY2 => s.sumY2,
      Tok.statSumY => s.sumY,
      Tok.statSumXY => s.sumXY,
      Tok.statSumX3 => s.sumX3,
      Tok.statSumX2Y => s.sumX2Y,
      Tok.statSumX4 => s.sumX4,
      Tok.statMeanX => s.meanX,
      Tok.statSigmaX => s.sigmaX,
      Tok.statSampleX => s.sampleX,
      Tok.statMeanY => s.meanY,
      Tok.statSigmaY => s.sigmaY,
      Tok.statSampleY => s.sampleY,
      Tok.regA => s.a,
      Tok.regB => s.b,
      Tok.regC => s.c,
      Tok.regR => s.r,
      Tok.statMinX => s.minX,
      Tok.statMaxX => s.maxX,
      Tok.statMinY => s.minY,
      Tok.statMaxY => s.maxY,
      _ => throw ArgumentError('not a statistic: $tok'),
    };
  }

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
    _pushValue(
      ctx.exactForms && !value.isInteger
          ? Value.frac(Frac.fromDec(value))
          : Value.dec(value),
      start,
    );
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
    if (v.isLinear &&
        values.where((x) => x.isLinear).length >= linearStackSize) {
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
      Tok.logicNot => (a) => _int(~_toInt(a)),
      Tok.logicNeg => (a) => _int(-_toInt(a)),
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
      Tok.sqrt => (a) {
        if (ctx.exactForms && !a.isComplex && !a.isLinear) {
          final e = a.frac ?? (a.dec.isInteger ? Frac.fromDec(a.dec) : null);
          if (e != null && !e.isNegative) {
            final r = Surd.sqrtOf(e);
            if (r != null) return Value.fromSurd(r);
          }
        }
        return _d1(sqrtDec)(a);
      },
      Tok.cbrt => _d1(cbrtDec),
      Tok.rnd => _d1((a) => roundForDisplay(a, ctx.format)),
      Tok.cAbs =>
        (a) => a.isMatrix
            ? Value.matrix(matAbs(a.matrix!))
            : a.isVector
            ? Value.dec(vecAbs(a.vector!))
            : Value.dec(a.magnitude()),
      Tok.det =>
        (a) => a.isMatrix
            ? Value.dec(matDet(a.matrix!))
            : throw const CalcError(CalcErrorKind.math),
      Tok.trn =>
        (a) => a.isMatrix
            ? Value.matrix(matTranspose(a.matrix!))
            : throw const CalcError(CalcErrorKind.math),
      Tok.cArg => (a) => Value.dec(a.argument(u)),
      Tok.conjg => (a) => a.conjugate(),
      _ => throw ArgumentError('not a prefix token: $tok'),
    };
  }

  Value Function(Value) _postfixFn(Tok tok) {
    final u = ctx.angle;
    final eng = _engExponents[tok];
    if (eng != null) return _d1((a) => a * Dec(BigInt.one, eng));
    if (tok.name.startsWith('est') || tok == Tok.toT) {
      return _d1((a) {
        final s = ctx.stats ?? (throw const CalcError(CalcErrorKind.math));
        return switch (tok) {
          Tok.estX => s.estimateX(a),
          Tok.estX1 => s.estimateX1(a),
          Tok.estX2 => s.estimateX2(a),
          Tok.estY => s.estimateY(a),
          _ => s.toT(a),
        };
      });
    }
    if (tok.name.startsWith('conv')) {
      return _d1((a) => _convert(Tok.conversions.indexOf(tok) + 1, a));
    }
    return switch (tok) {
      Tok.square => (a) => a.powInt(2) ?? Value.dec(squareDec(a.dec)),
      Tok.cube => (a) => a.powInt(3) ?? Value.dec(cubeDec(a.dec)),
      Tok.reciprocal => (a) => a.powInt(-1) ?? Value.dec(reciprocalDec(a.dec)),
      Tok.factorial => _d1(factorialDec),
      Tok.degMark => _d1((a) => convertAngle(a, AngleUnit.deg, u)),
      Tok.radMark => _d1((a) => convertAngle(a, AngleUnit.rad, u)),
      Tok.graMark => _d1((a) => convertAngle(a, AngleUnit.gra, u)),
      // Textbook-display %: x% = x ÷ 100 (exact for fractions).
      Tok.percentOf => (a) => a.fractionOver(Value.dec(Dec.fromInt(100))),
      _ => throw ArgumentError('not a postfix token: $tok'),
    };
  }

  _Op _binaryOp(Tok tok, int pos) {
    if (ctx.base != null) {
      final op = _baseOp(tok, pos);
      if (op != null) return op;
    }
    return _decimalOp(tok, pos);
  }

  /// BASE mode: 32-bit integer arithmetic and logic.
  _Op? _baseOp(Tok tok, int pos) {
    _Op op(int priority, int Function(int, int) f) => _Op(
      _OpType.binary,
      priority,
      pos,
      (a, b) => _int(f(_toInt(a), _toInt(b))),
    );
    return switch (tok) {
      Tok.add => op(Priority.addSubtract, (a, b) => a + b),
      Tok.subtract => op(Priority.addSubtract, (a, b) => a - b),
      Tok.multiply => op(Priority.multiplyDivide, (a, b) => a * b),
      Tok.divide => op(Priority.multiplyDivide, (a, b) {
        if (b == 0) throw const CalcError(CalcErrorKind.math);
        return a ~/ b;
      }),
      Tok.logicAnd => op(Priority.logicAnd, (a, b) => a & b),
      Tok.logicOr => op(Priority.logicOr, (a, b) => a | b),
      Tok.logicXor => op(Priority.logicOr, (a, b) => a ^ b),
      Tok.logicXnor => op(Priority.logicOr, (a, b) => ~(a ^ b)),
      _ => null,
    };
  }

  /// Parses a BASE-mode literal: [d|h|b|o] digits (decimal part dropped).
  int _baseLiteral(int start) {
    var i = start;
    var base = ctx.base!;
    final prefix = tokens[i];
    if (prefix.kind == TokKind.basePrefix) {
      base = switch (prefix) {
        Tok.baseH => 16,
        Tok.baseB => 2,
        Tok.baseO => 8,
        _ => 10,
      };
      i++;
    }
    final digits = StringBuffer();
    var sawPoint = false;
    while (i < tokens.length) {
      final t = tokens[i];
      if (t == Tok.point) {
        if (sawPoint) _syntax(i);
        sawPoint = true;
      } else if (t.kind == TokKind.digit || t.kind == TokKind.hexDigit) {
        final v = t.kind == TokKind.digit
            ? t.digit!
            : 10 + t.index - Tok.hexA.index;
        if (v >= base) _syntax(i);
        if (!sawPoint) digits.write(v.toRadixString(16));
      } else if (t == Tok.exp) {
        _syntax(i);
      } else {
        break;
      }
      i++;
    }
    if (digits.isEmpty) _syntax(i);
    _guard(
      start,
      () => _pushValue(
        baseInputValue(digits.toString(), base, wide: ctx.wideBase),
        start,
      ),
    );
    return i;
  }

  _Op _decimalOp(Tok tok, int pos) => switch (tok) {
    Tok.dot => _Op(_OpType.binary, Priority.dotProduct, pos, (a, b) {
      if (!a.isVector || !b.isVector) throw const CalcError(CalcErrorKind.math);
      return Value.dec(vecDot(a.vector!, b.vector!));
    }),
    Tok.angle => _Op(_OpType.binary, Priority.permutation, pos, (r, theta) {
      if (r.isComplex || theta.isComplex) {
        throw const CalcError(CalcErrorKind.math);
      }
      return Value.polar(r.dec, theta.dec, ctx.angle);
    }),
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
    Tok.fracDiv => _Op(
      _OpType.binary,
      Priority.fraction,
      pos,
      (a, b) => a.fractionOver(b),
    ),
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

/// CONV n applied to [x] (manual p.43-44).
Dec _convert(int n, Dec x) {
  if (n == 37) return (x - Dec.fromInt(32)) / Dec.parse('1.8'); // °F ▶ °C
  if (n == 38) return x * Dec.parse('1.8') + Dec.fromInt(32); // °C ▶ °F
  final (num, den) = conversionFactors[(n - 1) ~/ 2];
  final a = Dec.parse(num), b = Dec.parse(den);
  return n.isOdd ? x * a / b : x * b / a;
}

/// Simpson's rule with N = 2^[n] intervals; [n] null = increase N until the
/// result settles (up to 2^9).
Dec _simpson(Wide Function(Wide) f, Wide a, Wide b, int? n) {
  if (a == b) return Dec.zero;
  final width = b - a;
  // Trapezoid sums T_k with 2^k intervals; Simpson S_k = (4T_k − T_{k−1}) / 3.
  var intervals = 1;
  var trapezoid = (f(a) + f(b)) * Wide.half * width;
  Wide? previousSimpson;
  final three = Wide.fromInt(3), four = Wide.fromInt(4);
  for (var k = 1; k <= 9; k++) {
    final h = width / Wide.fromInt(intervals * 2);
    var midSum = Wide.zero;
    for (var i = 0; i < intervals; i++) {
      midSum = midSum + f(a + h * Wide.fromInt(2 * i + 1));
    }
    final next = trapezoid * Wide.half + h * midSum;
    final simpson = (four * next - trapezoid) / three;
    trapezoid = next;
    intervals *= 2;
    if (n != null) {
      if (k == n) return simpson.toDec();
      continue;
    }
    final prev = previousSimpson;
    if (prev != null && k >= 3) {
      final diff = (simpson - prev).abs();
      if (diff <= simpson.abs() * Wide.parse('1e-12') || diff.isZero) {
        return simpson.toDec();
      }
    }
    previousSimpson = simpson;
  }
  return previousSimpson!.toDec();
}

/// Central difference with one Richardson step: (4·D(h/2) − D(h)) / 3.
Dec _derivative(Wide Function(Wide) f, Wide a, Dec? step) {
  var h = step == null
      ? Wide.parse('1e-3') * (a.abs() > Wide.one ? a.abs() : Wide.one)
      : Wide.fromDec(step.abs());
  if (h.isZero) h = Wide.parse('1e-3');
  Wide central(Wide h) => (f(a + h) - f(a - h)) / (Wide.two * h);
  final coarse = central(h), fine = central(h * Wide.half);
  return ((Wide.fromInt(4) * fine - coarse) / Wide.fromInt(3)).toDec();
}

/// 32-bit signed range of BASE mode.
const int _baseMin = -2147483648;
const int _baseMax = 2147483647;

int _toInt(Value v) => v.dec.toInt();

Value _int(int v) {
  if (v < _baseMin || v > _baseMax) throw const CalcError(CalcErrorKind.math);
  return Value.dec(Dec.fromInt(v));
}

/// Digits allowed per base and the two's-complement width used for display.
const baseDigits = {2: 10, 8: 10, 16: 8, 10: 10};
const _baseBits = {2: 10, 8: 30, 16: 32};

/// Textbook models: 16-bit binary, 32-bit octal and hexadecimal.
const wideBaseDigits = {2: 16, 8: 11, 16: 8, 10: 10};
const wideBaseBits = {2: 16, 8: 32, 16: 32};

/// Value of a typed BASE literal ([digits] in hex notation of each digit).
Value baseInputValue(String digits, int base, {bool wide = false}) {
  final trimmed = digits.replaceFirst(RegExp('^0+(?=.)'), '');
  if (trimmed.length > (wide ? wideBaseDigits : baseDigits)[base]!) {
    throw const CalcError(CalcErrorKind.math);
  }
  // Each character is one digit (0-9, a-f), valid in [base].
  var v = int.parse(trimmed, radix: base);
  if (base != 10) {
    final bits = (wide ? wideBaseBits : _baseBits)[base]!;
    if (v >= 1 << (bits - 1)) v -= 1 << bits;
  }
  return _int(v);
}

/// Shows [v] in [base] (two's complement for 2/8/16), or throws Math ERROR
/// when it does not fit that base's range.
String baseOutput(Dec v, int base, {bool wide = false}) {
  final x = v.toInt();
  if (base == 10) return '$x';
  final bits = (wide ? wideBaseBits : _baseBits)[base]!;
  if (x < -(1 << (bits - 1)) || x >= 1 << (bits - 1)) {
    throw const CalcError(CalcErrorKind.math);
  }
  final text = (x & ((1 << bits) - 1)).toRadixString(base).toUpperCase();
  // Seven-segment style: b and d are lower case.
  return text.replaceAll('B', 'b').replaceAll('D', 'd');
}
