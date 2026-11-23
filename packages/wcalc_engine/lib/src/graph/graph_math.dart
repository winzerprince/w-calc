import 'dart:math' as math;

import '../angle_unit.dart';
import '../eval/evaluator.dart';
import '../input/token.dart';
import '../number/dec.dart';
import '../number/value.dart';

/// Formula text → calculator tokens, for typing functions on the graph
/// screen: `x^2-1`, `2sin(x)`, `sqrt(x)+1/x`, `y = ln(x)`.
List<Tok> parseFormula(String text) {
  var s = text.trim();
  final eq = RegExp(r'^\s*y\s*=', caseSensitive: false);
  s = s.replaceFirst(eq, '');
  final out = <Tok>[];
  bool operandEnded() =>
      out.isNotEmpty &&
      (out.last.kind == TokKind.digit ||
          out.last.kind == TokKind.point ||
          out.last == Tok.closeParen ||
          out.last.kind == TokKind.variable ||
          out.last.kind == TokKind.constant ||
          out.last.kind == TokKind.postfix);
  const words = {
    'asinh': [Tok.asinh],
    'acosh': [Tok.acosh],
    'atanh': [Tok.atanh],
    'arcsin': [Tok.asin],
    'arccos': [Tok.acos],
    'arctan': [Tok.atan],
    'asin': [Tok.asin],
    'acos': [Tok.acos],
    'atan': [Tok.atan],
    'sinh': [Tok.sinh],
    'cosh': [Tok.cosh],
    'tanh': [Tok.tanh],
    'sin': [Tok.sin],
    'cos': [Tok.cos],
    'tan': [Tok.tan],
    'sqrt': [Tok.sqrt],
    'cbrt': [Tok.cbrt],
    'abs': [Tok.cAbs],
    'exp': [Tok.ePow],
    'log': [Tok.log],
    'ln': [Tok.ln],
    'pi': [Tok.pi],
  };
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    final d = int.tryParse(c);
    if (d != null) {
      out.add(Tok.digits[d]);
      i++;
      continue;
    }
    final lower = s.substring(i).toLowerCase();
    final word = words.keys.where(lower.startsWith).firstOrNull;
    if (word != null) {
      out.addAll(words[word]!);
      i += word.length;
      continue;
    }
    switch (c) {
      case '.':
        out.add(Tok.point);
      case 'x' || 'X':
        out.add(Tok.varX);
      case 'π':
        out.add(Tok.pi);
      case 'e':
        out.add(Tok.e);
      case '+':
        out.add(Tok.add);
      case '-' || '−':
        out.add(operandEnded() ? Tok.subtract : Tok.negative);
      case '*' || '×' || '·':
        out.add(Tok.multiply);
      case '/' || '÷':
        out.add(Tok.divide);
      case '^':
        out.add(Tok.power);
      case '(':
        out.add(Tok.openParen);
      case ')':
        out.add(Tok.closeParen);
      case '!':
        out.add(Tok.factorial);
      case '²':
        out.add(Tok.square);
      case '³':
        out.add(Tok.cube);
      case '√':
        out.add(Tok.sqrt);
      default:
        throw FormatException('Unexpected "$c"', text, i);
    }
    i++;
  }
  if (out.isEmpty) throw FormatException('Empty formula', text);
  return out;
}

/// y = f(x) for plotting. Uses a fast double-precision version of the
/// expression when every token is supported, otherwise the exact
/// calculator evaluator. Undefined points give null (a gap).
class GraphFunction {
  GraphFunction(
    this.tokens, {
    this.angle = AngleUnit.rad,
    Map<String, Value> variables = const {},
  }) : _vars = variables,
       _fast = _Compiler(tokens, angle).compile();

  final List<Tok> tokens;
  final AngleUnit angle;
  final Map<String, Value> _vars;
  final double Function(double)? _fast;

  /// Whether the fast path is used.
  bool get isFast => _fast != null;

  double? at(double x) {
    final f = _fast;
    if (f != null) {
      final y = f(x);
      return y.isFinite ? y : null;
    }
    try {
      final v = evaluateValue(
        tokens,
        EvalContext(
          angle: angle,
          variables: {
            ..._vars,
            'X': Value.dec(Dec.parse(x.toStringAsPrecision(15))),
          },
        ),
      );
      if (v.isComplex || v.isLinear) return null;
      return double.parse(v.dec.toString());
    } on Object {
      return null;
    }
  }

  /// Roots in [a, b]: sign changes between [n] samples refined by bisection.
  List<double> roots(double a, double b, {int n = 400}) {
    final out = <double>[];
    double? px, py;
    for (var k = 0; k <= n; k++) {
      final x = a + (b - a) * k / n;
      final y = at(x);
      if (y != null && py != null && px != null) {
        if (y == 0) {
          out.add(x);
        } else if (py != 0 &&
            py.sign != y.sign &&
            (y - py).abs() < 1e6 * (b - a) / n + y.abs() + py.abs()) {
          final r = _bisect(px, x, py);
          if (r != null) out.add(r);
        }
      }
      px = x;
      py = y;
    }
    // Merge near-duplicates.
    final tol = (b - a) * 1e-9;
    final merged = <double>[];
    for (final r in out) {
      if (merged.isEmpty || (r - merged.last).abs() > tol) merged.add(r);
    }
    return merged;
  }

  double? _bisect(double lo, double hi, double flo) {
    for (var k = 0; k < 60; k++) {
      final mid = (lo + hi) / 2;
      final fm = at(mid);
      if (fm == null) return null;
      if (fm == 0) return mid;
      if (fm.sign == flo.sign) {
        lo = mid;
        flo = fm;
      } else {
        hi = mid;
      }
    }
    final r = (lo + hi) / 2;
    final fr = at(r);
    // Reject poles (sign change through infinity).
    return fr != null && fr.abs() < 1e-6 ? r : null;
  }

  /// Local maxima and minima in [a, b] (x, y, isMax).
  List<(double, double, bool)> extrema(double a, double b, {int n = 400}) {
    final out = <(double, double, bool)>[];
    final h = (b - a) / n;
    double? y0, y1;
    for (var k = 0; k <= n; k++) {
      final y2 = at(a + h * k);
      if (y0 != null && y1 != null && y2 != null) {
        final isMax = y1 > y0 && y1 >= y2;
        final isMin = y1 < y0 && y1 <= y2;
        if (isMax || isMin) {
          // Golden-section refinement around the middle sample.
          var lo = a + h * (k - 2), hi = a + h * k;
          for (var it = 0; it < 50; it++) {
            final m1 = lo + (hi - lo) * 0.382, m2 = lo + (hi - lo) * 0.618;
            final f1 = at(m1), f2 = at(m2);
            if (f1 == null || f2 == null) break;
            if (isMax ? f1 > f2 : f1 < f2) {
              hi = m2;
            } else {
              lo = m1;
            }
          }
          final x = (lo + hi) / 2;
          final y = at(x);
          if (y != null) out.add((x, y, isMax));
        }
      }
      y0 = y1;
      y1 = y2;
    }
    return out;
  }
}

/// Points where [f] and [g] cross in [a, b].
List<Offset2> intersections(
  GraphFunction f,
  GraphFunction g,
  double a,
  double b,
) {
  final diff = _Diff(f, g);
  return [
    for (final x in diff.roots(a, b, n: 300))
      if (f.at(x) case final y?) (x: x, y: y),
  ];
}

/// A plain (x, y) pair (the engine has no Flutter types).
typedef Offset2 = ({double x, double y});

class _Diff extends GraphFunction {
  _Diff(this.f, this.g) : super(const []);

  final GraphFunction f;
  final GraphFunction g;

  @override
  double? at(double x) {
    final a = f.at(x), b = g.at(x);
    return a == null || b == null ? null : a - b;
  }
}

/// Compiles calculator tokens to a double function (common functions only).
class _Compiler {
  _Compiler(this.t, this.angle);

  final List<Tok> t;
  final AngleUnit angle;
  int _i = 0;

  double Function(double)? compile() {
    try {
      final f = _expr(0);
      if (_i != t.length) return null;
      return f;
    } on _Unsupported {
      return null;
    }
  }

  Tok? get _peek => _i < t.length ? t[_i] : null;

  static const _binary = {
    Tok.add: 10,
    Tok.subtract: 10,
    Tok.multiply: 20,
    Tok.divide: 20,
    Tok.fracDiv: 40,
    Tok.power: 50,
    Tok.xRoot: 50,
  };

  bool _startsOperand(Tok? k) =>
      k != null &&
      (k.kind == TokKind.digit ||
          k == Tok.point ||
          k == Tok.varX ||
          k == Tok.pi ||
          k == Tok.e ||
          k == Tok.openParen ||
          k.kind == TokKind.prefix && k != Tok.negative);

  double Function(double) _expr(int minPrec) {
    var left = _unary();
    while (true) {
      final k = _peek;
      int? prec = _binary[k];
      // Implied multiplication: 2x, 3sin(x), x(x+1).
      final implied = prec == null && _startsOperand(k);
      if (implied) prec = 30;
      if (prec == null || prec <= minPrec) break;
      if (!implied) _i++;
      final right = _expr(prec);
      final l = left;
      left = switch (implied ? Tok.multiply : k) {
        Tok.add => (x) => l(x) + right(x),
        Tok.subtract => (x) => l(x) - right(x),
        Tok.multiply => (x) => l(x) * right(x),
        Tok.divide || Tok.fracDiv => (x) => l(x) / right(x),
        Tok.power => (x) => _pow(l(x), right(x)),
        Tok.xRoot => (x) => _root(right(x), l(x)),
        _ => throw _Unsupported(),
      };
    }
    return left;
  }

  static double _pow(double a, double b) {
    if (a < 0 && b != b.roundToDouble()) {
      // Odd roots of negatives (x^(1/3)) stay real.
      final inv = 1 / b;
      if ((inv - inv.round()).abs() < 1e-9 && inv.round().isOdd) {
        return -math.pow(-a, b).toDouble();
      }
    }
    return math.pow(a, b).toDouble();
  }

  static double _root(double x, double n) => x < 0 && n.round().isOdd
      ? -math.pow(-x, 1 / n).toDouble()
      : math.pow(x, 1 / n).toDouble();

  double Function(double) _unary() {
    final k = _peek;
    if (k == Tok.negative) {
      _i++;
      final v = _expr(45); // binds tighter than × ÷, looser than ^
      return (x) => -v(x);
    }
    if (k != null && k.kind == TokKind.prefix) {
      _i++;
      final f = _prefix(k);
      final v = _peek == Tok.openParen ? _primary() : _expr(45);
      return _postfix((x) => f(v(x)));
    }
    return _postfix(_primary());
  }

  double Function(double) _postfix(double Function(double) v) {
    while (true) {
      final k = _peek;
      final g = switch (k) {
        Tok.square => (double y) => y * y,
        Tok.cube => (double y) => y * y * y,
        Tok.reciprocal => (double y) => 1 / y,
        Tok.factorial => (double y) => _factorial(y),
        _ => null,
      };
      if (g == null) return v;
      _i++;
      final inner = v;
      v = (x) => g(inner(x));
    }
  }

  static double _factorial(double n) {
    if (n < 0 || n != n.roundToDouble() || n > 170) return double.nan;
    var r = 1.0;
    for (var i = 2; i <= n; i++) {
      r *= i;
    }
    return r;
  }

  double Function(double) _primary() {
    final k = _peek;
    if (k == null) throw _Unsupported();
    if (k.kind == TokKind.digit || k == Tok.point) {
      final b = StringBuffer();
      while (_peek != null &&
          (_peek!.kind == TokKind.digit || _peek == Tok.point)) {
        b.write(_peek == Tok.point ? '.' : '${_peek!.digit}');
        _i++;
      }
      if (_peek == Tok.exp) {
        _i++;
        b.write('e');
        if (_peek == Tok.negative) {
          _i++;
          b.write('-');
        }
        while (_peek != null && _peek!.kind == TokKind.digit) {
          b.write('${_peek!.digit}');
          _i++;
        }
      }
      final v = double.parse(b.toString());
      return (_) => v;
    }
    _i++;
    switch (k) {
      case Tok.varX:
        return (x) => x;
      case Tok.pi:
        return (_) => math.pi;
      case Tok.e:
        return (_) => math.e;
      case Tok.openParen:
        final v = _expr(0);
        if (_peek == Tok.closeParen) _i++; // may be left open at the end
        return v;
      default:
        throw _Unsupported();
    }
  }

  double Function(double) _prefix(Tok k) {
    double toRad(double a) => switch (angle) {
      AngleUnit.deg => a * math.pi / 180,
      AngleUnit.gra => a * math.pi / 200,
      AngleUnit.rad => a,
    };
    double fromRad(double a) => switch (angle) {
      AngleUnit.deg => a * 180 / math.pi,
      AngleUnit.gra => a * 200 / math.pi,
      AngleUnit.rad => a,
    };
    return switch (k) {
      Tok.sin => (a) => math.sin(toRad(a)),
      Tok.cos => (a) => math.cos(toRad(a)),
      Tok.tan => (a) => math.tan(toRad(a)),
      Tok.asin => (a) => fromRad(math.asin(a)),
      Tok.acos => (a) => fromRad(math.acos(a)),
      Tok.atan => (a) => fromRad(math.atan(a)),
      Tok.sinh => (a) => (math.exp(a) - math.exp(-a)) / 2,
      Tok.cosh => (a) => (math.exp(a) + math.exp(-a)) / 2,
      Tok.tanh => (a) => 1 - 2 / (math.exp(2 * a) + 1),
      Tok.asinh => (a) => math.log(a + math.sqrt(a * a + 1)),
      Tok.acosh => (a) => math.log(a + math.sqrt(a * a - 1)),
      Tok.atanh => (a) => 0.5 * math.log((1 + a) / (1 - a)),
      Tok.ln => math.log,
      Tok.log => (a) => math.log(a) / math.ln10,
      Tok.sqrt => math.sqrt,
      Tok.cbrt =>
        (a) => a < 0
            ? -math.pow(-a, 1 / 3).toDouble()
            : math.pow(a, 1 / 3).toDouble(),
      Tok.cAbs => (a) => a.abs(),
      Tok.tenPow => (a) => math.pow(10, a).toDouble(),
      Tok.ePow => math.exp,
      _ => throw _Unsupported(),
    };
  }
}

class _Unsupported implements Exception {}
