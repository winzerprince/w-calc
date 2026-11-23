/// Meaning of one graph expression row: what to draw and how to compute
/// it. Rows are compiled to double closures over a shared [GxEnv]
/// (variables from sliders and definitions, user functions).
library;

import 'dart:math' as math;

import 'gx_input.dart';

/// A compiled expression.
typedef GxFn = double Function(GxEnv env);

/// Values seen by compiled expressions.
final class GxEnv {
  GxEnv({this.degrees = false});

  /// Trig in degrees.
  bool degrees;
  double x = 0;
  double y = 0;
  final Map<String, double> vars = {};
  final Map<String, GxUserFn> fns = {};
  int _depth = 0;

  double get _unit => degrees ? math.pi / 180 : 1;

  double get(String name) => switch (name) {
    'x' => x,
    'y' => y,
    _ => vars[name] ?? double.nan,
  };

  void set(String name, double v) {
    switch (name) {
      case 'x':
        x = v;
      case 'y':
        y = v;
      default:
        vars[name] = v;
    }
  }

  /// [name] bound to [v] while [f] runs.
  double bind(String name, double v, double Function() f) {
    final had = name == 'x' || name == 'y' || vars.containsKey(name);
    final old = get(name);
    set(name, v);
    try {
      return f();
    } finally {
      if (had) {
        set(name, old);
      } else {
        vars.remove(name);
      }
    }
  }
}

/// A function defined by a row such as `f(x) = x² + 1`.
final class GxUserFn {
  GxUserFn(this.params, this.body);

  final List<String> params;
  final GxFn body;

  double call(GxEnv env, List<double> args) {
    if (args.length != params.length || env._depth > 40) return double.nan;
    env._depth++;
    try {
      double run(int k) => k == params.length
          ? body(env)
          : env.bind(params[k], args[k], () => run(k + 1));
      return run(0);
    } finally {
      env._depth--;
    }
  }
}

/// What a row is.
enum GxShape {
  /// Nothing typed.
  empty,

  /// y = f(x) (or a relation y < f(x), …), [GxStatement.f] gives y.
  function,

  /// x = g(y) (or a relation), [GxStatement.f] gives x.
  xFunction,

  /// A relation between x and y: [GxStatement.f] is left − right.
  implicit,

  /// A point (a, b): [GxStatement.f] and [GxStatement.g].
  point,

  /// `b = 2.5`: a variable with a slider.
  slider,

  /// `c = 2b + 1`: a variable defined from others.
  define,

  /// `f(x) = …`; drawn too when its one parameter is x.
  userFunction,

  /// A constant expression: its value is shown.
  value,

  /// Not understood: [GxStatement.error].
  error,
}

/// `=`, `<`, `>`, `≤`, `≥`.
enum GxRel {
  eq('='),
  lt('<'),
  gt('>'),
  le('≤'),
  ge('≥');

  const GxRel(this.symbol);

  final String symbol;

  /// The same relation with its sides swapped.
  GxRel get flipped => switch (this) {
    eq => eq,
    lt => gt,
    gt => lt,
    le => ge,
    ge => le,
  };

  /// Whether the boundary itself belongs (solid line).
  bool get inclusive => this == eq || this == le || this == ge;

  bool holds(double d) => switch (this) {
    eq => d == 0,
    lt => d < 0,
    gt => d > 0,
    le => d <= 0,
    ge => d >= 0,
  };
}

/// The analysed row.
final class GxStatement {
  const GxStatement._(
    this.shape, {
    this.f,
    this.g,
    this.rel,
    this.name,
    this.params = const [],
    this.number,
    this.used = const {},
    this.error,
  });

  final GxShape shape;
  final GxFn? f;
  final GxFn? g;
  final GxRel? rel;

  /// Defined variable or function name.
  final String? name;
  final List<String> params;

  /// Slider start value.
  final double? number;

  /// Every variable the row reads (including x and y), not counting
  /// bound ones (Σ index, ∫ variable, function parameters).
  final Set<String> used;
  final String? error;

  bool get isPlot =>
      shape == GxShape.function ||
      shape == GxShape.xFunction ||
      shape == GxShape.implicit ||
      shape == GxShape.point;

  /// Variables a slider could be offered for.
  Set<String> free(Set<String> defined) =>
      used.difference({'x', 'y', ...defined});

  @override
  String toString() =>
      'GxStatement($shape${rel == null ? '' : ' ${rel!.symbol}'}'
      '${name == null ? '' : ' $name'}${error == null ? '' : ' "$error"'})';
}

/// Function names a row defines (`f(x) = …` → f), for parsing calls in
/// the other rows.
String? gxDefinedFunction(GxRow row) => _fnHead(row.items)?.$1;

/// Name, parameters and the index of `=` of a `f(x, y) = …` row.
(String, List<String>, int)? _fnHead(List<GxNode> items) {
  var k = 0;
  String? letter(int at) =>
      at < items.length && items[at] is GxSym && (items[at] as GxSym).isLetter
      ? (items[at] as GxSym).text
      : null;
  final name = letter(k);
  if (name == null || name == 'x' || name == 'y') return null;
  k++;
  var full = name;
  if (items.elementAtOrNull(k) case GxBox(kind: GxKind.sub, :final slots)) {
    full = '${name}_${slots[0]}';
    k++;
  }
  if (k >= items.length || items[k] != const GxSym('(')) return null;
  k++;
  final params = <String>[];
  while (true) {
    final p = letter(k);
    if (p == null) return null;
    params.add(p);
    k++;
    if (k < items.length && items[k] == const GxSym(',')) {
      k++;
      continue;
    }
    break;
  }
  if (k >= items.length || items[k] != const GxSym(')')) return null;
  k++;
  if (k >= items.length || items[k] != const GxSym('=')) return null;
  return (full, params, k);
}

const _rels = {
  '=': GxRel.eq,
  '<': GxRel.lt,
  '>': GxRel.gt,
  '≤': GxRel.le,
  '≥': GxRel.ge,
};

/// Works out what [row] means. [functions] are the names of functions
/// defined by other rows.
GxStatement gxAnalyse(GxRow row, {Set<String> functions = const {}}) {
  final items = row.items;
  if (items.isEmpty) return const GxStatement._(GxShape.empty);
  try {
    final head = _fnHead(items);
    if (head != null) {
      final (name, params, eq) = head;
      final p = _Parser(items.sublist(eq + 1), {...functions, name})
        ..bound.addAll(params);
      final body = p.parseAll();
      return GxStatement._(
        GxShape.userFunction,
        f: body,
        name: name,
        params: params,
        used: p.used,
      );
    }

    // Split at the relation sign.
    var depth = 0, at = -1;
    for (var k = 0; k < items.length; k++) {
      final it = items[k];
      if (it is! GxSym) continue;
      if (it.text == '(') depth++;
      if (it.text == ')') depth--;
      if (depth == 0 && _rels.containsKey(it.text)) {
        if (at >= 0) throw const _Err('Use one = or inequality per line');
        at = k;
      }
    }

    if (at < 0) {
      if (_point(items, functions) case final pt?) return pt;
      final p = _Parser(items, functions);
      final f = p.parseAll();
      if (p.used.contains('y')) {
        throw const _Err('Add “=” or an inequality to plot with y');
      }
      return GxStatement._(
        p.used.contains('x') ? GxShape.function : GxShape.value,
        f: f,
        used: p.used,
      );
    }

    final rel = _rels[(items[at] as GxSym).text]!;
    final left = items.sublist(0, at), right = items.sublist(at + 1);
    if (left.isEmpty || right.isEmpty) throw const _Err('Incomplete');
    final lp = _Parser(left, functions), rp = _Parser(right, functions);
    final lf = lp.parseAll(), rf = rp.parseAll();
    final lone = _loneName(left), rone = _loneName(right);
    final used = {...lp.used, ...rp.used};

    GxStatement? side(String? name, _Parser other, GxFn f, GxRel r) {
      if (name == 'y' && !other.used.contains('y')) {
        return GxStatement._(GxShape.function, f: f, rel: r, used: used);
      }
      if (name == 'x' && !other.used.contains('x')) {
        return GxStatement._(GxShape.xFunction, f: f, rel: r, used: used);
      }
      return null;
    }

    if (side(lone, rp, rf, rel) ?? side(rone, lp, lf, rel.flipped)
        case final s?) {
      return s;
    }
    if (lone != null && lone != 'x' && lone != 'y' && rel == GxRel.eq) {
      if (rp.used.contains('x') || rp.used.contains('y')) {
        throw _Err('$lone can’t depend on x or y; use y = … to plot');
      }
      if (rp.used.contains(lone)) throw _Err('$lone is defined by itself');
      final literal = _literal(right);
      return GxStatement._(
        literal == null ? GxShape.define : GxShape.slider,
        f: rf,
        name: lone,
        number: literal,
        used: rp.used,
      );
    }
    if (!used.contains('x') && !used.contains('y')) {
      throw const _Err('Nothing to plot: use x or y');
    }
    return GxStatement._(
      GxShape.implicit,
      f: (e) => lf(e) - rf(e),
      rel: rel,
      used: used,
    );
  } on _Err catch (e) {
    return GxStatement._(GxShape.error, error: e.message);
  }
}

/// `(a, b)` on its own.
GxStatement? _point(List<GxNode> items, Set<String> functions) {
  if (items.first != const GxSym('(') || items.last != const GxSym(')')) {
    return null;
  }
  var depth = 0, comma = -1;
  for (var k = 0; k < items.length; k++) {
    final it = items[k];
    if (it == const GxSym('(')) depth++;
    if (it == const GxSym(')')) {
      depth--;
      if (depth == 0 && k != items.length - 1) return null;
    }
    if (depth == 1 && it == const GxSym(',')) {
      if (comma >= 0) throw const _Err('Points have two coordinates');
      comma = k;
    }
  }
  if (comma < 0) return null;
  final xp = _Parser(items.sublist(1, comma), functions);
  final yp = _Parser(items.sublist(comma + 1, items.length - 1), functions);
  final fx = xp.parseAll(), fy = yp.parseAll();
  return GxStatement._(
    GxShape.point,
    f: fx,
    g: fy,
    used: {...xp.used, ...yp.used},
  );
}

/// A single variable name (`b`, `a₁`).
String? _loneName(List<GxNode> items) {
  if (items.isEmpty || items.length > 2) return null;
  final first = items.first;
  if (first is! GxSym || !first.isLetter) return null;
  if (items.length == 1) return first.text;
  if (items[1] case GxBox(kind: GxKind.sub, :final slots)) {
    return '${first.text}_${slots[0]}';
  }
  return null;
}

/// A plain number, possibly negative.
double? _literal(List<GxNode> items) {
  final text = items.map((e) => e is GxSym ? e.text : '?').join();
  if (!RegExp(r'^-?(\d+\.?\d*|\.\d+)$').hasMatch(text)) return null;
  return double.parse(text);
}

class _Err implements Exception {
  const _Err(this.message);

  final String message;
}

/// Recursive-descent compiler for one row.
class _Parser {
  _Parser(this.items, this.functions);

  final List<GxNode> items;
  final Set<String> functions;
  final Set<String> used = {};
  final Set<String> bound = {};
  int i = 0;

  GxNode? get _peek => i < items.length ? items[i] : null;

  bool _is(String s) => _peek == GxSym(s);

  GxFn parseAll() {
    if (items.isEmpty) throw const _Err('Incomplete');
    final f = _expr();
    if (i < items.length) {
      throw _Err('Unexpected “${_peek is GxSym ? _peek : 'box'}”');
    }
    return f;
  }

  /// Compiles [row] with this parser's bound names and functions.
  GxFn _sub(GxRow row, {Set<String> extra = const {}}) {
    final p = _Parser(row.items, functions)..bound.addAll({...bound, ...extra});
    final f = p.parseAll();
    used.addAll(p.used);
    return f;
  }

  GxFn _expr() {
    var l = _term();
    while (true) {
      if (_is('+') || _is('-')) {
        final plus = _is('+');
        i++;
        final a = l, b = _term();
        l = plus ? (e) => a(e) + b(e) : (e) => a(e) - b(e);
      } else {
        return l;
      }
    }
  }

  bool _startsPrimary(GxNode? n) => switch (n) {
    null => false,
    GxBox(:final kind) => kind != GxKind.pow && kind != GxKind.sub,
    GxSym(:final text) =>
      n.isDigit ||
          n.isLetter ||
          n.isWord ||
          text == '.' ||
          text == '(' ||
          text == 'π',
  };

  GxFn _term() {
    var l = _signed();
    while (true) {
      final a = l;
      if (_is('×') || _is('÷')) {
        final times = _is('×');
        i++;
        final b = _signed();
        l = times ? (e) => a(e) * b(e) : (e) => a(e) / b(e);
      } else if (_startsPrimary(_peek)) {
        final b = _power();
        l = (e) => a(e) * b(e);
      } else {
        return l;
      }
    }
  }

  GxFn _signed() {
    if (_is('-')) {
      i++;
      final v = _signed();
      return (e) => -v(e);
    }
    if (_is('+')) {
      i++;
      return _signed();
    }
    return _power();
  }

  GxFn _power() => _postfix(_primary());

  GxFn _postfix(GxFn v) {
    while (true) {
      final n = _peek;
      if (n case GxBox(kind: GxKind.pow, :final slots)) {
        i++;
        final b = v, x = _sub(slots[0]);
        v = (e) => _pow(b(e), x(e));
      } else if (n == const GxSym('!')) {
        i++;
        final b = v;
        v = (e) => _gamma(b(e) + 1);
      } else {
        return v;
      }
    }
  }

  GxFn _primary() {
    final n = _peek;
    switch (n) {
      case null:
        throw const _Err('Incomplete');
      case GxBox():
        i++;
        return _box(n);
      case GxSym(:final text):
        if (n.isDigit || text == '.') return _number();
        if (n.isWord) return _function(text);
        if (n.isLetter) return _variable();
        i++;
        switch (text) {
          case 'π':
            return (_) => math.pi;
          case '(':
            final v = _expr();
            if (_is(',')) throw const _Err('A point can’t be used in a sum');
            if (_is(')')) i++;
            return v;
        }
        throw _Err('Unexpected “$text”');
    }
  }

  GxFn _number() {
    final b = StringBuffer();
    while (true) {
      final d = _peek;
      if (d is! GxSym || !(d.isDigit || d.text == '.')) break;
      b.write(d.text);
      i++;
    }
    final v = double.tryParse(b.toString());
    if (v == null) throw _Err('“$b” isn’t a number');
    return (_) => v;
  }

  GxFn _variable() {
    var name = (_peek as GxSym).text;
    i++;
    if (_peek case GxBox(kind: GxKind.sub, :final slots)) {
      i++;
      name = '${name}_${slots[0]}';
    }
    if (functions.contains(name) && _is('(')) {
      i++;
      final args = <GxFn>[_expr()];
      while (_is(',')) {
        i++;
        args.add(_expr());
      }
      if (_is(')')) i++;
      return (e) {
        final f = e.fns[name];
        return f == null ? double.nan : f.call(e, [for (final a in args) a(e)]);
      };
    }
    if (name == 'e' && !bound.contains('e')) return (_) => math.e;
    if (!bound.contains(name)) used.add(name);
    return switch (name) {
      'x' => (e) => e.x,
      'y' => (e) => e.y,
      _ => (e) => e.get(name),
    };
  }

  GxFn _box(GxBox b) {
    final s = b.slots;
    switch (b.kind) {
      case GxKind.frac:
        final n = _sub(s[0]), d = _sub(s[1]);
        return (e) => n(e) / d(e);
      case GxKind.sqrt:
        final v = _sub(s[0]);
        return (e) => math.sqrt(v(e));
      case GxKind.root:
        final n = _sub(s[0]), v = _sub(s[1]);
        return (e) => _root(v(e), n(e));
      case GxKind.abs:
        final v = _sub(s[0]);
        return (e) => v(e).abs();
      case GxKind.sum || GxKind.prod:
        final lower = s[0].items;
        final name = _loneName(
          lower.takeWhile((x) => x != const GxSym('=')).toList(),
        );
        final eq = lower.indexOf(const GxSym('='));
        if (name == null || eq < 0) throw const _Err('Write the start as n=1');
        final from = _sub(GxRow(lower.sublist(eq + 1)));
        final to = _sub(s[1]);
        final body = _sub(s[2], extra: {name});
        final sum = b.kind == GxKind.sum;
        return (e) {
          final a = from(e).round(), z = to(e).round();
          if (z - a > 100000) return double.nan;
          var acc = sum ? 0.0 : 1.0;
          for (var k = a; k <= z; k++) {
            final v = e.bind(name, k.toDouble(), () => body(e));
            acc = sum ? acc + v : acc * v;
          }
          return acc;
        };
      case GxKind.integral:
        final name = _loneName(s[3].items);
        if (name == null) throw const _Err('Write the variable after d');
        final lo = _sub(s[0]), hi = _sub(s[1]);
        final body = _sub(s[2], extra: {name});
        return (e) {
          final a = lo(e), z = hi(e);
          if (!a.isFinite || !z.isFinite) return double.nan;
          const n = 128;
          final h = (z - a) / n;
          var acc = 0.0;
          for (var k = 0; k <= n; k++) {
            final w = k == 0 || k == n ? 1 : (k.isOdd ? 4 : 2);
            acc += w * e.bind(name, a + k * h, () => body(e));
          }
          return acc * h / 3;
        };
      case GxKind.deriv:
        final body = _sub(s[0]);
        used.add('x');
        return (e) {
          final x0 = e.x, h = 1e-4 * math.max(1, x0.abs());
          final a = e.bind('x', x0 + h, () => body(e));
          final c = e.bind('x', x0 - h, () => body(e));
          return (a - c) / (2 * h);
        };
      case GxKind.pow || GxKind.sub:
        throw const _Err('Missing base');
    }
  }

  GxFn _function(String w) {
    i++;
    GxFn? power;
    var inverse = false;
    GxFn? base;
    if (_peek case GxBox(kind: GxKind.pow, :final slots)) {
      i++;
      if (slots[0].toText() == '-1' && _invertible.contains(w)) {
        inverse = true;
      } else {
        power = _sub(slots[0]);
      }
    }
    if (_peek case GxBox(kind: GxKind.sub, :final slots) when w == 'log') {
      i++;
      base = _sub(slots[0]);
    }
    final List<GxFn> args;
    if (_is('(')) {
      i++;
      args = [_expr()];
      while (_is(',')) {
        i++;
        args.add(_expr());
      }
      if (_is(')')) i++;
    } else {
      if (!_startsPrimary(_peek)) throw _Err('$w needs an argument');
      var v = _power();
      while (_startsPrimary(_peek) &&
          !(_peek is GxSym && (_peek as GxSym).isWord)) {
        final a = v, b = _power();
        v = (e) => a(e) * b(e);
      }
      args = [v];
    }
    final name = inverse ? 'arc$w' : w;
    final f = _apply(name, args, base);
    if (power == null) return f;
    final p = power;
    return (e) => _pow(f(e), p(e));
  }

  static const _invertible = {
    'sin', 'cos', 'tan', 'csc', 'sec', 'cot', //
    'sinh', 'cosh', 'tanh',
  };

  GxFn _apply(String w, List<GxFn> args, GxFn? base) {
    final want = switch (w) {
      'mod' => 2,
      'min' || 'max' => -1,
      _ => 1,
    };
    if (want > 0 && args.length != want) {
      throw _Err('$w takes $want argument${want == 1 ? '' : 's'}');
    }
    final a = args.first;
    if (w == 'min' || w == 'max') {
      final mn = w == 'min';
      return (e) {
        var r = a(e);
        for (final f in args.skip(1)) {
          final v = f(e);
          r = mn ? math.min(r, v) : math.max(r, v);
        }
        return r;
      };
    }
    if (w == 'mod') {
      final b = args[1];
      return (e) {
        final x = a(e), m = b(e);
        return x - m * (x / m).floorToDouble();
      };
    }
    if (w == 'log' && base != null) {
      final bf = base;
      return (e) => math.log(a(e)) / math.log(bf(e));
    }
    final double Function(double, GxEnv) g = switch (w) {
      'sin' => (v, e) => math.sin(v * e._unit),
      'cos' => (v, e) => math.cos(v * e._unit),
      'tan' => (v, e) => math.tan(v * e._unit),
      'csc' => (v, e) => 1 / math.sin(v * e._unit),
      'sec' => (v, e) => 1 / math.cos(v * e._unit),
      'cot' => (v, e) => 1 / math.tan(v * e._unit),
      'arcsin' => (v, e) => math.asin(v) / e._unit,
      'arccos' => (v, e) => math.acos(v) / e._unit,
      'arctan' => (v, e) => math.atan(v) / e._unit,
      'arccsc' => (v, e) => math.asin(1 / v) / e._unit,
      'arcsec' => (v, e) => math.acos(1 / v) / e._unit,
      'arccot' => (v, e) => math.atan(1 / v) / e._unit,
      'sinh' => (v, _) => (math.exp(v) - math.exp(-v)) / 2,
      'cosh' => (v, _) => (math.exp(v) + math.exp(-v)) / 2,
      'tanh' => (v, _) => _tanh(v),
      'csch' => (v, _) => 2 / (math.exp(v) - math.exp(-v)),
      'sech' => (v, _) => 2 / (math.exp(v) + math.exp(-v)),
      'coth' => (v, _) => 1 / _tanh(v),
      'arcsinh' => (v, _) => math.log(v + math.sqrt(v * v + 1)),
      'arccosh' => (v, _) => math.log(v + math.sqrt(v * v - 1)),
      'arctanh' => (v, _) => 0.5 * math.log((1 + v) / (1 - v)),
      'ln' => (v, _) => math.log(v),
      'log' => (v, _) => math.log(v) / math.ln10,
      'exp' => (v, _) => math.exp(v),
      'floor' => (v, _) => v.floorToDouble(),
      'ceil' => (v, _) => v.ceilToDouble(),
      'round' => (v, _) => v.roundToDouble(),
      'sign' => (v, _) => v.sign,
      _ => throw _Err('Unknown function $w'),
    };
    return (e) => g(a(e), e);
  }

  static double _tanh(double v) => 1 - 2 / (math.exp(2 * v) + 1);

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

  /// Γ(z) (Lanczos), so x! is defined for non-integers too.
  static double _gamma(double z) {
    if (z.isNaN) return z;
    if (z == z.roundToDouble()) {
      if (z <= 0) return double.nan;
      if (z > 171) return double.infinity;
      var r = 1.0;
      for (var k = 2; k < z; k++) {
        r *= k;
      }
      return r;
    }
    if (z < 0.5) return math.pi / (math.sin(math.pi * z) * _gamma(1 - z));
    const g = 7.0;
    const c = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.9843695780195716e-6,
      1.5056327351493116e-7,
    ];
    final x = z - 1;
    var a = c[0];
    final t = x + g + 0.5;
    for (var k = 1; k < 9; k++) {
      a += c[k] / (x + k);
    }
    return math.sqrt(2 * math.pi) * math.pow(t, x + 0.5) * math.exp(-t) * a;
  }
}
