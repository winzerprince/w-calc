/// SD / REG statistics (manual p.46-55).
library;

import '../number/dec.dart';
import '../number/wide.dart';

enum RegressionType { lin, log, exp, pwr, inv, quad }

/// One registered data item (x, optional y for REG) with its frequency.
class StatItem {
  StatItem(this.x, {this.y, Dec? freq}) : freq = freq ?? Dec.one;

  final Dec x;
  final Dec? y;
  final Dec freq;

  StatItem copyWith({Dec? x, Dec? y, Dec? freq}) =>
      StatItem(x ?? this.x, y: y ?? this.y, freq: freq ?? this.freq);
}

Never _mathError() => throw const CalcError(CalcErrorKind.math);

Wide _w(Dec d) => Wide.fromDec(d);

/// Statistical memory plus all derived values.
class StatData {
  StatData({this.type = RegressionType.lin});

  RegressionType type;
  final List<StatItem> items = [];

  void add(StatItem item) => items.add(item);
  void clear() => items.clear();

  bool get isEmpty => items.isEmpty;

  // ---- raw sums (S-SUM) ----

  Wide _sum(Wide Function(StatItem) f) =>
      items.fold(Wide.zero, (s, i) => s + _w(i.freq) * f(i));

  Wide _y(StatItem i) => _w(i.y ?? Dec.zero);

  Dec get n => _sum((_) => Wide.one).toDec();
  Dec get sumX => _sum((i) => _w(i.x)).toDec();
  Dec get sumX2 => _sum((i) => _w(i.x) * _w(i.x)).toDec();
  Dec get sumX3 => _sum((i) => _w(i.x) * _w(i.x) * _w(i.x)).toDec();
  Dec get sumX4 {
    return _sum((i) {
      final x2 = _w(i.x) * _w(i.x);
      return x2 * x2;
    }).toDec();
  }

  Dec get sumY => _sum(_y).toDec();
  Dec get sumY2 => _sum((i) => _y(i) * _y(i)).toDec();
  Dec get sumXY => _sum((i) => _w(i.x) * _y(i)).toDec();
  Dec get sumX2Y => _sum((i) => _w(i.x) * _w(i.x) * _y(i)).toDec();

  // ---- means and deviations (S-VAR) ----

  Wide get _n {
    final n = _sum((_) => Wide.one);
    if (n.isZero) _mathError();
    return n;
  }

  Wide _mean(Wide Function(StatItem) f) => _sum(f) / _n;

  /// Σ f·(v − mean)² over the data.
  Wide _ss(Wide Function(StatItem) f) {
    final m = _mean(f);
    return _sum((i) {
      final dv = f(i) - m;
      return dv * dv;
    });
  }

  Dec get meanX => _mean((i) => _w(i.x)).toDec();
  Dec get meanY => _mean(_y).toDec();
  Dec get sigmaX => WideMath.sqrt(_ss((i) => _w(i.x)) / _n).toDec();
  Dec get sigmaY => WideMath.sqrt(_ss(_y) / _n).toDec();
  Dec get sampleX => _sample((i) => _w(i.x));
  Dec get sampleY => _sample(_y);

  Dec _sample(Wide Function(StatItem) f) {
    final n = _n;
    if (n <= Wide.one) _mathError();
    return WideMath.sqrt(_ss(f) / (n - Wide.one)).toDec();
  }

  /// x▶t: normalized variate (x − x̄) / xσn.
  Dec toT(Dec x) {
    final sigma = sigmaX;
    if (sigma.isZero) _mathError();
    return (_w(x) - _w(meanX)).toDec() / sigma;
  }

  // ---- regression ----

  Wide _tx(StatItem i) => switch (type) {
    RegressionType.log || RegressionType.pwr => _ln(i.x),
    RegressionType.inv => i.x.isZero ? _mathError() : Wide.one / _w(i.x),
    _ => _w(i.x),
  };

  Wide _ty(StatItem i) => switch (type) {
    RegressionType.exp || RegressionType.pwr => _ln(i.y ?? Dec.zero),
    _ => _y(i),
  };

  static Wide _ln(Dec v) {
    if (v <= Dec.zero) _mathError();
    return WideMath.ln(_w(v));
  }

  /// (A', B', r) of the linearised model y' = A' + B'·x'.
  (Wide, Wide, Wide) get _linear {
    final sxx = _ss(_tx), syy = _ss(_ty);
    final mx = _mean(_tx), my = _mean(_ty);
    final sxy = _sum((i) => (_tx(i) - mx) * (_ty(i) - my));
    if (sxx.isZero) _mathError();
    final b = sxy / sxx;
    final a = my - b * mx;
    final den = WideMath.sqrt(sxx * syy);
    final r = den.isZero ? _mathError() : sxy / den;
    return (a, b, r);
  }

  /// Quadratic least squares y = A + Bx + Cx² via centred normal equations.
  (Wide, Wide, Wide) get _quadratic {
    final mx = _mean((i) => _w(i.x)), my = _mean(_y);
    final n = _n;
    Wide m(Wide Function(Wide x, Wide y) f) =>
        _sum((i) => f(_w(i.x) - mx, _y(i) - my)) / n;
    final s2 = m((x, _) => x * x), s3 = m((x, _) => x * x * x);
    final s4 = m((x, _) => x * x * x * x);
    final t1 = m((x, y) => x * y), t2 = m((x, y) => x * x * y);
    // Solve for b, c in: b·s2 + c·s3 = t1 ; b·s3 + c·(s4 − s2²) = t2 (centred).
    final d22 = s4 - s2 * s2;
    final det = s2 * d22 - s3 * s3;
    if (det.isZero) _mathError();
    final c = (s2 * t2 - s3 * t1) / det;
    final bc = (t1 - c * s3) / s2;
    // Back to raw x: y = my + bc·(x−mx) + c·((x−mx)² − s2).
    final a = my - bc * mx + c * (mx * mx - s2);
    final b = bc - Wide.two * c * mx;
    return (a, b, c);
  }

  bool get _expA => type == RegressionType.exp || type == RegressionType.pwr;

  Dec get a {
    if (type == RegressionType.quad) return _quadratic.$1.toDec();
    final a = _linear.$1;
    return (_expA ? WideMath.exp(a) : a).toDec();
  }

  Dec get b =>
      (type == RegressionType.quad ? _quadratic.$2 : _linear.$2).toDec();

  Dec get c {
    if (type != RegressionType.quad) _mathError();
    return _quadratic.$3.toDec();
  }

  Dec get r {
    if (type == RegressionType.quad) _mathError();
    return _linear.$3.toDec();
  }

  /// ŷ for [x].
  Dec estimateY(Dec x) {
    final wx = _w(x);
    if (type == RegressionType.quad) {
      final (a, b, c) = _quadratic;
      return (a + b * wx + c * wx * wx).toDec();
    }
    final (a, b, _) = _linear;
    return switch (type) {
      RegressionType.lin => a + b * wx,
      RegressionType.log => a + b * _ln(x),
      RegressionType.exp => WideMath.exp(a + b * wx),
      RegressionType.pwr => WideMath.exp(a + b * _ln(x)),
      RegressionType.inv => x.isZero ? _mathError() : a + b / wx,
      RegressionType.quad => throw StateError('unreachable'),
    }.toDec();
  }

  /// x̂ for [y] (not quadratic; see [estimateX1] / [estimateX2]).
  Dec estimateX(Dec y) {
    if (type == RegressionType.quad) _mathError();
    final (a, b, _) = _linear;
    if (b.isZero) _mathError();
    final wy = _w(y);
    return switch (type) {
      RegressionType.lin => (wy - a) / b,
      RegressionType.log => WideMath.exp((wy - a) / b),
      RegressionType.exp => (_ln(y) - a) / b,
      RegressionType.pwr => WideMath.exp((_ln(y) - a) / b),
      RegressionType.inv => (wy - a).isZero ? _mathError() : b / (wy - a),
      RegressionType.quad => throw StateError('unreachable'),
    }.toDec();
  }

  Dec estimateX1(Dec y) => _quadRoot(y, 1);
  Dec estimateX2(Dec y) => _quadRoot(y, -1);

  Dec _quadRoot(Dec y, int sign) {
    if (type != RegressionType.quad) _mathError();
    final (a, b, c) = _quadratic;
    if (c.isZero) _mathError();
    final disc = b * b - Wide.fromInt(4) * c * (a - _w(y));
    if (disc.isNegative) _mathError();
    final root = WideMath.sqrt(disc);
    return ((-b + (sign > 0 ? root : -root)) / (Wide.two * c)).toDec();
  }
}

// ---- normal distribution (DISTR) ----

/// Φ(t) at working precision.
Wide _phi(Wide t) {
  if (t > Wide.fromInt(9)) return Wide.one;
  if (t < Wide.fromInt(-9)) return Wide.zero;
  // erf(z) series with z = t/√2: erf z = 2/√π Σ (−1)^k z^(2k+1) / (k!(2k+1)).
  final z = t / WideMath.sqrt(Wide.two);
  final z2 = z * z;
  final eps = Wide.parse('1e-30');
  var power = z, sum = z;
  for (var k = 1; k < 400; k++) {
    power = -(power * z2) / Wide.fromInt(k);
    final term = power / Wide.fromInt(2 * k + 1);
    sum = sum + term;
    if (term.abs() < eps) break;
  }
  final erf = Wide.two / WideMath.sqrt(Wide.pi) * sum;
  return (Wide.one + erf) * Wide.half;
}

/// The device shows normal-distribution probabilities to 5 decimals.
Dec _five(Wide v) => v.toDec().roundDecimals(5);

/// P(t): area from −∞ to t.
Dec normalP(Dec t) => _five(Wide.withPrecision(40, () => _phi(_w(t))));

/// Q(t): area between 0 and |t|.
Dec normalQ(Dec t) =>
    _five(Wide.withPrecision(40, () => (_phi(_w(t)) - Wide.half).abs()));

/// R(t): area from t to ∞.
Dec normalR(Dec t) =>
    _five(Wide.withPrecision(40, () => Wide.one - _phi(_w(t))));
